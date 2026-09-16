resource "aws_vpc" "vpc1" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.common_tags, {
    Name = "sentinelgrid-${var.environment}-vpc"
  })
}

# Internet Gateway per le Subnet Pubbliche
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.vpc1.id

  tags = merge(var.common_tags, {
    Name = "sentinelgrid-${var.environment}-igw"
  })
}

# Subnet (Pubbliche e Private)
resource "aws_subnet" "subnet" {
  for_each = var.subnets

  vpc_id            = aws_vpc.vpc1.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(var.common_tags, {
    Name                              = "sentinelgrid-${var.environment}-${each.key}"
    "kubernetes.io/role/elb"          = can(regex("public", each.key)) ? "1" : null
    "kubernetes.io/role/internal-elb" = can(regex("private", each.key)) ? "1" : null
  })
}

# Elastic IP per NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(var.common_tags, { Name = "sentinelgrid-${var.environment}-nat-eip" })
}

# NAT Gateway per permettere ai nodi privati di uscire su Internet
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values({ for k, v in aws_subnet.subnet : k => v.id if can(regex("public", k)) })[0]

  tags = merge(var.common_tags, { Name = "sentinelgrid-${var.environment}-nat-gw" })
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, { Name = "sentinelgrid-${var.environment}-public-rt" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc1.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(var.common_tags, { Name = "sentinelgrid-${var.environment}-private-rt" })
}

resource "aws_route_table_association" "assoc" {
  for_each = aws_subnet.subnet

  subnet_id      = each.value.id
  route_table_id = can(regex("public", each.key)) ? aws_route_table.public.id : aws_route_table.private.id
}