mock_provider "aws" {}

run "splits_txt_on_a_255_octet_boundary" {
  command = plan

  variables {
    domain             = "example.com"
    github_pages_cname = ""
    records = {
      long = {
        name = "long.example.com"
        type = "TXT"
        records = [
          "${join("", [for unused in range(255) : "a"])}b",
        ]
      }
    }
  }

  assert {
    condition = (
      substr(local.chunk_txt["${join("", [for unused in range(255) : "a"])}b"], 255, 2) == "\"\""
      && substr(local.chunk_txt["${join("", [for unused in range(255) : "a"])}b"], 257, 1) == "b"
    )
    error_message = "TXT longer than 255 octets must be split with the provider's \"\" marker on that boundary."
  }
}

run "pages_records_follow_the_cname" {
  command = plan

  variables {
    domain             = "example.com"
    github_pages_cname = "soinkleined.github.io"
  }

  assert {
    condition     = length(aws_route53_record.github_pages_a) == 1 && length(aws_route53_record.github_pages_aaaa) == 1 && length(aws_route53_record.www) == 1
    error_message = "A GitHub Pages CNAME should publish apex A, apex AAAA, and www."
  }

  assert {
    condition     = one(aws_route53_record.www[0].records) == "soinkleined.github.io"
    error_message = "www should CNAME to the Pages hostname passed in."
  }
}

run "omits_pages_records_without_a_cname" {
  command = plan

  variables {
    domain             = "example.com"
    github_pages_cname = ""
  }

  assert {
    condition     = length(aws_route53_record.github_pages_a) == 0 && length(aws_route53_record.www) == 0 && length(aws_route53_record.github_pages_aaaa) == 0
    error_message = "Pages records should be absent until github_pages_cname is set."
  }
}
