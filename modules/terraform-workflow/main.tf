locals {
  triggers_autopopulate     = var.config.triggers_autopopulate
  trigger_dirs_autopopulate = local.triggers_autopopulate && var.config.trigger_dirs_autopopulate

  trigger_dirs = distinct(compact(concat([
    var.config["trigger_dir"],
    ], var.config["trigger_dirs"], local.trigger_dirs_autopopulate ? [
    for _, workspace_data in var.config["workspaces"] : workspace_data["workspace_dir"]
  ] : [])))

  workspaces = {
    for workspace_name, workspace_data in var.config["workspaces"] : workspace_name => merge(workspace_data, {
      job_name = replace(workspace_data["job_name"], ".", "-")

      dependencies = [
        for dependency_name in workspace_data["dependencies"] : replace(dependency_name, ".", "-")
      ]
    })
  }

  workspace_branches = distinct([
    for _, workspace_data in var.config["workspaces"] : workspace_data["workspace_branch"]
  ])

  trigger_branches_autopopulate = local.triggers_autopopulate && var.config.trigger_branches_autopopulate

  workflow_config = merge(var.config, {
    workflow_name    = var.workflow_name
    triggers         = distinct(concat(var.config["triggers"], formatlist("%s/**", local.trigger_dirs)))
    trigger_branches = local.trigger_branches_autopopulate ? distinct(concat(local.workspace_branches, var.config.trigger_branches)) : var.config.trigger_branches
    jobs = {
      for _, workspace_data in local.workspaces : workspace_data["job_name"] => workspace_data
    }
  })

  job_dependencies_base = {
    no_deps = {
      for job_name, _ in local.workflow_config["jobs"] : job_name => {}
    }

    deps = {
      for job_name, job_data in local.workflow_config["jobs"] : job_name => {
        needs = job_data["dependencies"]
      }
    }
  }

  job_dependencies_keys = {
    for job_name, job_data in local.workflow_config["jobs"] : job_name => length(job_data["dependencies"]) > 0 ? "deps" : "no_deps"
  }

  job_dependencies_yaml = {
    for job_name, dependencies_key in local.job_dependencies_keys : job_name => local.job_dependencies_base[dependencies_key][job_name]
  }

  workflow_dispatch_triggers_base = {
    no_dispatch = {}
    has_dispatch = {
      workflow_dispatch = {}
    }
  }

  workflow_dispatch_trigger_key = var.config.trigger_on_dispatch ? "has_dispatch" : "no_dispatch"

  workflow_dispatch_triggers = local.workflow_dispatch_triggers_base[local.workflow_dispatch_trigger_key]

  workflow_call_triggers_base = {
    no_call = {}
    has_call = {
      workflow_call = {}
    }
  }

  workflow_call_trigger_key = var.config.trigger_on_call ? "has_call" : "no_call"

  workflow_call_triggers = local.workflow_call_triggers_base[local.workflow_call_trigger_key]

  workflow_schedule_triggers_base = {
    no_schedule = {}
    has_schedule = {
      schedule = [
        for schedule in var.config.run_schedules : {
          cron = schedule
        }
      ]
    }
  }

  workflow_schedule_trigger_key = length(var.config.run_schedules) > 0 ? "has_schedule" : "no_schedule"

  workflow_schedule_triggers = local.workflow_schedule_triggers_base[local.workflow_schedule_trigger_key]

  workflow_path_triggers_base = {
    no_paths = {}
    has_paths = {
      paths = local.workflow_config["triggers"]
    }
  }

  workflow_path_trigger_key = length(local.workflow_config["triggers"]) > 0 ? "has_paths" : "no_paths"

  workflow_path_triggers = local.workflow_path_triggers_base[local.workflow_path_trigger_key]

  workflow_branches_triggers_base = {
    no_branches = {}
    has_branches = {
      branches = local.workflow_config["trigger_branches"]
    }
  }

  workflow_branches_trigger_key = length(local.workflow_config["trigger_branches"]) > 0 ? "has_branches" : "no_branches"

  workflow_branches_triggers = local.workflow_branches_triggers_base[local.workflow_branches_trigger_key]

  workflow_tags_triggers_base = {
    no_tags = {}
    has_tags = {
      tags = local.workflow_config["trigger_tags"]
    }
  }

  workflow_tags_trigger_key = length(local.workflow_config["trigger_tags"]) > 0 ? "has_tags" : "no_tags"

  workflow_tags_triggers = local.workflow_tags_triggers_base[local.workflow_tags_trigger_key]

  trigger_on_release = var.config.trigger_on_release && !var.config.publish_release

  trigger_on_completion = length(local.workflow_config["trigger_on_workflow_completion"]) > 0 && !var.config.publish_release

  workflow_on_completion_triggers_base = {
    no_on_completion = {}
    has_on_completion = {
      workflow_run = {
        workflows = local.workflow_config["trigger_on_workflow_completion"]
        types = [
          "completed",
        ]
      }
    }
  }

  workflow_on_completion_trigger_key = length(local.workflow_config["trigger_on_workflow_completion"]) > 0 ? "has_on_completion" : "no_on_completion"

  workflow_on_completion_triggers = local.workflow_on_completion_triggers_base[local.workflow_on_completion_trigger_key]

  workflow_on_release_triggers_base = {
    no_on_release = {}
    has_on_release = {
      release = {
        types = [
          "published",
        ]
      }
    }
  }

  workflow_on_release_trigger_key = local.trigger_on_release ? "has_on_release" : "no_on_release"

  workflow_on_release_triggers = local.workflow_on_release_triggers_base[local.workflow_on_release_trigger_key]

  workflow_workspace_base_data = {
    for job_name, job_data in local.workflow_config["jobs"] : job_name => merge(yamldecode(templatefile("${path.module}/templates/workflow_workspace_base.yml", job_data)), job_data)
  }

  call_workflow_pull_request_yaml = merge({
    for workflow_path in var.config.call_workflows_before : format("%s_before", replace(trimsuffix(basename(workflow_path), ".yml"), "-", "_")) => {
      uses    = "./${replace(workflow_path, "manual-only", "pull-request")}"
      secrets = "inherit"
    }
    }, {
    for workflow_path in var.config.call_workflows_after : format("%s_after", replace(trimsuffix(basename(workflow_path), ".yml"), "-", "_")) => {
      uses    = "./${replace(workflow_path, "manual-only", "pull-request")}"
      secrets = "inherit"
      needs   = keys(local.workflows_yaml_push_event_base_jobs)
    }
  })

  call_workflow_before_pull_request_jobs = [
    for job_name, _ in local.call_workflow_pull_request_yaml : job_name if endswith(job_name, "_before")
  ]

  workflow_pull_requests_base_triggers = {
    has_call = local.workflow_call_triggers
    no_call = {
      pull_request = local.workflow_path_triggers
    }
  }

  workflow_pull_requests_triggers = local.workflow_pull_requests_base_triggers[local.workflow_call_trigger_key]

  workflows_yaml_base_event_configurations = {
    pull_request = {
      on = local.workflow_pull_requests_triggers

      jobs = merge(local.call_workflow_pull_request_yaml, {
        for job_name, base_data in local.workflow_workspace_base_data : job_name => merge(base_data["base"], local.job_dependencies_yaml[job_name], {
          needs = distinct(concat(local.call_workflow_before_pull_request_jobs, lookup(base_data, "needs", [])))
          steps = concat(base_data["steps"]["setup"], base_data["steps"]["pull_request"], base_data["steps"]["save"])
        })
      })
    }
  }

  workflows_yaml_push_event_triggers = merge(local.workflow_call_triggers,
    local.workflow_dispatch_triggers, {
      push = merge(local.workflow_path_triggers, local.workflow_branches_triggers, local.workflow_tags_triggers)
  })

  workflows_yaml_push_event_job_outcomes = [
    "save",
    "publish",
  ]

  workflows_yaml_push_event_base_jobs = {
    for job_name, base_data in local.workflow_workspace_base_data : job_name => merge(base_data["base"], local.job_dependencies_yaml[job_name], {
      steps = flatten(concat(base_data["steps"]["setup"], base_data["steps"]["push"], base_data["steps"]["save"]))
    })
  }

  publish_yaml = yamldecode(templatefile("${path.module}/files/publish.yml", {
    tag_prefix = var.config.release_tag_prefix
  }))

  call_workflow_yaml = merge({
    for workflow_path in var.config.call_workflows_before : format("%s-before", replace(trimsuffix(basename(workflow_path), ".yml"), "_", "-")) => {
      uses    = "./${workflow_path}"
      secrets = "inherit"
    }
    }, {
    for workflow_path in var.config.call_workflows_after : format("%s-after", replace(trimsuffix(basename(workflow_path), ".yml"), "_", "-")) => {
      uses    = "./${workflow_path}"
      secrets = "inherit"
      needs   = keys(local.workflows_yaml_push_event_base_jobs)
    }
  })

  call_workflow_before_jobs = [
    for job_name, _ in local.call_workflow_yaml : job_name if endswith(job_name, "_before")
  ]

  workflows_yaml_push_event_jobs = merge({
    for job_name, job_data in local.workflows_yaml_push_event_base_jobs : job_name => merge(job_data, length(local.call_workflow_before_jobs) > 0 ? {
      needs = distinct(concat(local.call_workflow_before_jobs, lookup(job_data, "needs", [])))
    } : {})
  }, local.call_workflow_yaml)

  workflows_yaml = merge(local.workflows_yaml_base_event_configurations, {
    push = {
      on = local.workflows_yaml_push_event_triggers

      jobs = local.workflows_yaml_push_event_jobs
    }

    manual_only = {
      on = merge(local.workflow_call_triggers, local.workflow_dispatch_triggers)

      jobs = local.workflows_yaml_push_event_jobs
    }

    manual_release = {
      on = merge(local.workflow_call_triggers, local.workflow_dispatch_triggers)

      jobs = merge(local.workflows_yaml_push_event_jobs, {
        publish = merge(local.publish_yaml, {
          needs = distinct(concat(keys(local.workflows_yaml_push_event_jobs), keys(local.call_workflow_yaml)))
        })
      })
    }

    publish = {
      on = merge(local.workflow_call_triggers, local.workflow_dispatch_triggers, local.workflow_on_completion_triggers, local.workflow_on_release_triggers)

      jobs = local.workflows_yaml_push_event_jobs
    }

    release = {
      on = merge(local.workflows_yaml_push_event_triggers, local.workflow_schedule_triggers)

      jobs = merge(local.workflows_yaml_push_event_jobs, {
        publish = merge(local.publish_yaml, {
          needs = distinct(concat(keys(local.workflows_yaml_push_event_jobs), keys(local.call_workflow_yaml)))
        })
      })
    }
  })

  trigger_on_publish = local.trigger_on_release || local.trigger_on_completion
  trigger_on_push    = !var.config.publish_release && !local.trigger_on_publish

  workflow_base_keys = {
    all = {
      for key in compact(flatten(concat(var.config.trigger_on_pull_request ? ["pull_request"] : [],
        local.trigger_on_push ? ["push"] : [],
        local.trigger_on_publish ? ["publish"] : [],
      var.config.publish_release ? ["release"] : []))) : key => replace(key, "_", "-")
    }

    manual_only = {
      pull_request = "pull-request"
      manual_only  = "manual-only"
    }

    manual_release = {
      pull_request   = "pull-request"
      manual_release = "manual-release"
    }
  }

  workflow_keys_key = var.config.no_automatic_triggers ? (var.config.publish_release ? "manual_release" : "manual_only") : "all"

  workflow_keys = local.workflow_base_keys[local.workflow_keys_key]

  workflow_file_name = replace(var.workflow_name, "_", "-")

  workflow_yaml_files = {
    for key, key_file_name in local.workflow_keys : format("%s-%s.yml", local.workflow_file_name, key_file_name) => replace(yamlencode(merge(local.workflows_yaml[key], {
      name = "${local.workflow_file_name}-on-${key_file_name}"

      concurrency = var.config.trigger_on_call ? "${var.config.concurrency_group}-${local.workflow_file_name}" : var.config.concurrency_group
    })), "/((?:^|\n)[\\s-]*)\"([\\w-]+)\":/", "$1$2:")
  }

  workflow_files = [
    {
      ".github/workflows" = local.workflow_yaml_files
    }
  ]
}
