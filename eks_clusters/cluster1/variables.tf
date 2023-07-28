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

variable configure_multicluster_allocation {
    type = bool
    default = true
}

variable cluster_name {
    type = string
    default = "agones-gameservers-1"
}

variable cluster_region {
    type = string
    default = "us-east-1"
}

variable secondary_cluster_name {
    type = string
    default = "agones-gameservers-2"
}

variable secondary_cluster_region {
    type = string
    default = "us-east-2"
}