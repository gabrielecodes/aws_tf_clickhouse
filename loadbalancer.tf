# Target group
resource "aws_lb_target_group" "clickhouse_tg" {
  name        = "clickhouse-tg"
  port        = var.secure_tcp_port
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "TCP"
    port                = var.secure_tcp_port
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 10
  }

  tags = {
    Name = "${var.project}-clickHouse-target-group"
  }
}

# Network Load Balancer
resource "aws_lb" "clickhouse_nlb" {
  name               = "clickhouse-nlb"
  load_balancer_type = "network"

  subnets  = [for s in aws_subnet.private : s.id]
  internal = false

  tags = {
    Name = "ClickHouse-Network-Load-Balancer"
  }
}

# Target Group Attachment
resource "aws_lb_target_group_attachment" "clickhouse_targets" {
  for_each = aws_instance.clickhouse_node

  target_group_arn = aws_lb_target_group.clickhouse_tg.arn
  target_id        = each.key   # The instance ID (e.g., i-0abc123)
  port             = each.value # The secure port (e.g., 9440)
}
