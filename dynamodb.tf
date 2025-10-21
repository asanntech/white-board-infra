# ==============================================================================
# DynamoDB Table (Primary)
# ==============================================================================

resource "aws_dynamodb_table" "primary" {
  name         = var.dynamodb_table_name
  billing_mode = var.dynamodb_billing_mode

  hash_key  = "room_id"
  range_key = "drawing_id"

  attribute {
    name = "room_id"
    type = "S"
  }
  attribute {
    name = "drawing_id"
    type = "S"
  }

  point_in_time_recovery { enabled = true }

  server_side_encryption { enabled = true }

  dynamic "ttl" {
    for_each = var.dynamodb_ttl_attribute == "" ? [] : [1]
    content {
      enabled        = true
      attribute_name = var.dynamodb_ttl_attribute
    }
  }

  tags = {
    Name        = var.dynamodb_table_name
    Project     = var.project_name
    Environment = var.environment
  }
}


