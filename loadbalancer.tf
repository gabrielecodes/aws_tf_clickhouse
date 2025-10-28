# Target group
resource "aws_lb_target_group" "clickhouse_tg" {
  name        = "clickhouse-tg"
  port        = var.secure_tcp_port
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.id
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

  subnets  = [aws_subnet.public.id]
  internal = false

  tags = {
    Name = "ClickHouse-Network-Load-Balancer"
  }
}

# Target Group Attachment
resource "aws_lb_target_group_attachment" "clickhouse_targets" {
  for_each = {
    for k, v in aws_instance.clickhouse_node :
    k => v
  }

  target_group_arn = aws_lb_target_group.clickhouse_tg.arn
  target_id        = each.value.id
  port             = var.secure_tcp_port
}

# Listener Resource
resource "aws_lb_listener" "secure_tcp_listener" {
  load_balancer_arn = aws_lb.clickhouse_nlb.arn
  port              = var.secure_tcp_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.clickhouse_tg.arn
  }
}
