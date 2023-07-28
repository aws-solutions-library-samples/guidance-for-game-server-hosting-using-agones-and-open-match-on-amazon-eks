variable namespaces {
  type = list
  default = []
}

variable configure_agones {
  type = bool
  default = true
}

variable configure_open_match{
  type = bool
  default = true
}

variable cluster_name {
  type = string
  default = "agones-gameservers-1"
}

variable cluster_region {
  type = string
  default = "us-east-2"
}

variable ecr_region {
  type = string
  default = "us-east-1"
}
