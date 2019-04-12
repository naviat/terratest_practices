# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN APPLICATION LOAD BALANCER
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_alb" "lb" {
  name               = "${var.name}"
  load_balancer_type = "application"
  idle_timeout       = "${var.idle_timeout}"

  internal        = "${var.internal}"
  security_groups = ["${aws_security_group.sg.id}"]
  subnets         = ["${var.subnet_ids}"]

  enable_http2    = "${var.enable_http2}"
  ip_address_type = "${var.ip_address_type}"

  tags = "${var.tags}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE HTTP LISTENERS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_alb_listener" "http" {
  count = "${length(var.http_listener_ports)}"

  load_balancer_arn = "${aws_alb.lb.arn}"
  port              = "${element(var.http_listener_ports, count.index)}"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${length(var.default_target_group_arn) > 0 ? var.default_target_group_arn : element(concat(aws_alb_target_group.black_hole.*.arn, list("")), 0)}"
    type             = "forward"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A "BLACK HOLE" TARGET GROUP
# The Load Balancer requires "default route" for requests that don't match any listener rules. We let the user the
# default target group for these routes via var.default_target_group_arn, but if the user doesn't specify one, we
# still need to send the requests somewhere. The solution is to optionally create this "black hole" target group that
# has no servers registered in it.
#
# Any requests that go to this target group will get a 503, so this is a poor user experience, and we recommend most
# users specify var.default_target_group_arn instead. Ideally, var.default_target_group_arn points to something that
# can serve up a reasonable 404 page.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_alb_target_group" "black_hole" {
  count = "${length(var.default_target_group_arn) == 0 ? 1 : 0}"

  name     = "${var.name}-hole"
  protocol = "HTTP"
  port     = 12345
  vpc_id   = "${var.vpc_id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP TO CONTROL TRAFFIC THAT CAN GO IN AND OUT OF THE LOAD BALANCER
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "sg" {
  name   = "${var.name}-lb"
  vpc_id = "${var.vpc_id}"
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = "${aws_security_group.sg.id}"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_http_inbound_from_cidr_blocks" {
  count             = "${length(var.http_listener_ports)}"
  type              = "ingress"
  from_port         = "${element(var.http_listener_ports, count.index)}"
  to_port           = "${element(var.http_listener_ports, count.index)}"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.sg.id}"
  cidr_blocks       = ["${var.allow_inbound_from_cidr_blocks}"]
}

resource "aws_security_group_rule" "allow_http_inbound_from_security_groups" {
  count                    = "${length(var.http_listener_ports) * var.allow_inbound_from_security_groups_num}"
  type                     = "ingress"
  from_port                = "${element(var.http_listener_ports, count.index)}"
  to_port                  = "${element(var.http_listener_ports, count.index)}"
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.sg.id}"
  source_security_group_id = "${element(var.allow_inbound_from_security_groups, count.index)}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE OPTIONAL DNS A RECORDS IN ROUTE 53 POINTING AT THE LOAD BALANCER
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "load_balancer" {
  count   = "${length(var.route53_records)}"
  name    = "${lookup(var.route53_records[count.index], "domain")}"
  zone_id = "${lookup(var.route53_records[count.index], "zone_id")}"
  type    = "A"

  alias {
    name                   = "${aws_alb.lb.dns_name}"
    zone_id                = "${aws_alb.lb.zone_id}"
    evaluate_target_health = true
  }
}
