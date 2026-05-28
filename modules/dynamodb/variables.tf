variable "table_name" {
  type = string
}

variable "environment" {
  type    = string
  default = "dev"
}

# variable "inventory_seed" {
#   description = "Initial product catalogue with stock levels"
#   type = map(object({
#     stock       = number
#     price       = number
#     description = string
#   }))
#   default = {
#     "Widget A" = { stock = 100, price = 9.99,  description = "Standard widget, blue"   }
#     "Widget B" = { stock = 50,  price = 24.99, description = "Premium widget, black"   }
#     "Gadget X" = { stock = 30,  price = 49.99, description = "Electronic gadget, gen1" }
#     "Gadget Y" = { stock = 20,  price = 99.99, description = "Electronic gadget, gen2" }
#     "Doohickey"= { stock = 200, price = 4.99,  description = "Multipurpose doohickey"  }
#   }
# }
