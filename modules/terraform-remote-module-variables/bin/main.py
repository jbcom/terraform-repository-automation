#!/usr/bin/python3.9

from ntpath import join
import sys
import requests
from requests.structures import CaseInsensitiveDict
import hcl2
from io import StringIO
import json
import logging
from base64 import b64encode
from datetime import datetime
import os
from collections.abc import Mapping
import shlex
import subprocess


def get_logger(log_file):
    logger = logging.getLogger(__name__)
    os.makedirs(os.path.dirname(log_file), exist_ok=True)
    file_handler = logging.FileHandler(log_file, mode='w')
    logger.propagate = True
    logger.addHandler(file_handler)
    logger.setLevel(logging.DEBUG)
    now = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
    logger.info(f"New run at {now}")
    return logger


def get_cmd_output(cmd):
    cmd = shlex.split(cmd)
    return subprocess.run(cmd, capture_output=True).stdout.decode('ascii', 'ignore').strip()


def strtobool(val):
    if isinstance(val, bool):
        return val

    val = val.lower()
    if val in ('y', 'yes', 't', 'true', 'on', '1'):
        return True
    elif val in ('n', 'no', 'f', 'false', 'off', '0'):
        return False
    else:
        raise ValueError("invalid truth value %r" % (val,))


class RemoteModuleConfig:

    def __init__(self, log_file, repository_name, repository_tag, variable_files, defaults, overrides, local_module_source, parameter_generators, map_name_to, map_sanitized_name_to, github_token=''):
        self.logger = get_logger(log_file)
        self.defaults = json.loads(defaults)
        self.overrides = json.loads(overrides)
        self.parameter_generators = json.loads(parameter_generators)
        self.map_name_to = json.loads(map_name_to)
        self.map_sanitized_name_to = json.loads(map_sanitized_name_to)
        self.github_token = github_token

        variable_files = json.loads(variable_files)

        self.defaults_config = {}
        self.variables_config = {}
        self.descriptions_config = {}

        self.variables = self.get_variables(variable_files, local_module_source, repository_name, repository_tag)
        self.log_results(self.variables, 'Variables')
        self.log_results(self.defaults, 'Defaults')
        self.log_results(self.overrides, 'Overrides')
        self.log_results(self.parameter_generators, 'Parameter Generators')
        self.log_results(self.map_name_to, 'Map Name To')
        self.log_results(self.map_sanitized_name_to, 'Map Sanitized Name To')


    def get_config_from_variables(self, variable_data, source_path):
        variables = {}

        if isinstance(variable_data, list):
            for nested_variable_data in variable_data:
                variables = variables | self.get_config_from_variables(nested_variable_data, source_path)

            return variables

        for key, params in variable_data.items():
            type = self.decode_type_param(params['type'])

            default = params.get('default', None)

            if isinstance(default, list) and len(default) > 0:
                self.logger.info(f"Defaults: '{default}' is inside a list, getting it out")
                try:
                    default = default[0]
                except IndexError as exc:
                    raise RuntimeError(f"failed to extract default from list: {default}") from exc

            if type.startswith('list(') or type.startswith('optional(list(') and not isinstance(default, list):
                self.logger.info(f"Type: {type} is a list and default: '{default}' isn't, putting it inside of one")
                default = [default]

            description = params['description'] or ''
            if isinstance(description, list):
                self.logger.info(f"Description: '{description}' is inside a list, getting it out")
                description = description[0]

            defaults = self.defaults.get(key, {})
            overrides = self.overrides.get(key, {})

            parameters = {
                "type": type,
                "source": os.path.basename(source_path),
                "default_value": overrides.get('default_value', defaults.get('default_value', default)),
                "default_generator": overrides.get('default_generator', defaults.get('default_generator')),
                "override_value": overrides.get('override_value', defaults.get('override_value')),
                "required": overrides.get('required', defaults.get('required', False)),
                "description": description,
                "internal": False,
                "parameter_generator": self.parameter_generators.get(key, overrides.get('parameter_generator', defaults.get('parameter_generator'))),
            }

            self.log_results(parameters, f"Parameters for '{key}'")

            variables[key] = parameters

        return variables


    def get_variables(self, variable_files, local_module_source, repository_name, repository_tag):
        self.logger.info(f"Processing variable files: {variable_files}")

        locals = []
        urls = []

        if local_module_source != "":
            local_repository_root = get_cmd_output('git rev-parse --show-toplevel')
            local_module_source = os.path.join(local_repository_root, local_module_source)
            self.logger.info(f"Retrieving variable files data from local module source: '{local_module_source}'")
            locals = [f"{local_module_source}/{file_name}" for file_name in variable_files]
        else:
            remote_module_source = f"https://raw.githubusercontent.com/{repository_name}/{repository_tag}"

            self.logger.info(f"Retrieving variable files data from URL source: '{remote_module_source}'")
            urls = [f"{remote_module_source}/{file_name}" for file_name in variable_files]

        self.logger.info(f"Locals: {locals}, URLs: {urls}")

        variables = {}

        headers = CaseInsensitiveDict()

        if self.github_token != '':
            headers['Authorization'] = f"token {self.github_token}"

        for url in urls:
            resp = requests.get(url, headers=headers)
            variables = variables | self.get_config_from_variables(hcl2.load(StringIO(resp.content.decode('ascii', 'ignore')))["variable"], url)

        for local in locals:
            with open(local, 'r') as file:
                variables = variables | self.get_config_from_variables(hcl2.load(file)["variable"], local)
        
        return variables


    def convert(self):
        results = self.variables

        for variable_name, variable_data in self.defaults.items():
            if strtobool(variable_data.get('remove', False)):
                self.logger.info(f"Variable '{variable_name}' is flagged for removal")
                results.pop(variable_name, None)
                continue

            if variable_name not in results:
                self.logger.info(f"{variable_name} from defaults not in results, injecting it")
                results[variable_name] = variable_data
            else:
                for k, v in variable_data.items():
                    if k not in results[variable_name]:
                            self.logger.info(f"{variable_name} missing parameter '{k}', using '{v}' from defaults")
                            results[variable_name][k] = v
        
        self.log_results(results, 'Results after merging in missing defaults')

        for variable_name, variable_data in self.overrides.items():
            if strtobool(variable_data.get('remove', False)):
                self.logger.info(f"Variable '{variable_name}' is flagged for removal")
                results.pop(variable_name, None)
                continue
            
            if variable_name not in results:
                self.logger.info(f"{variable_name} from overrides not in results, injecting it")
                results[variable_name] = variable_data
            else:
                for k, v in variable_data.items():
                    self.logger.info(f"Overriding '{k}' for {variable_name} with '{v}' from overrides")
                    results[variable_name][k] = v
        
        self.log_results(results, 'Results after merging in missing overrides')

        base_variable_data = {
            "source": None,
            "override_value"      : None,
            "default_generator"   : None,
            "parameter_generator" : None,
            "internal"            : False,
            "required"            : False
        }

        required_variable_data = [
            'type',
            'default_value',
        ]

        for variable_name, variable_data in results.copy().items():
            default_generator = self.map_sanitized_name_to.get(variable_name, self.map_name_to.get(variable_name, variable_data.get("default_generator")))
            results[variable_name]["default_generator"] = default_generator

            for k in required_variable_data:
                if k not in results[variable_name]:
                    raise RuntimeError(f"Required parameter '{k}' not in variable '{variable_name}' with data: {variable_data}")

            for k, v in base_variable_data.items():
                if k not in variable_data:
                    self.logger.info(f"Variable '{variable_name}' missing '{k}', setting it to '{v}'")
                    results[variable_name][k] = v

            if default_generator:
                default = None
            else:
                default = variable_data['default_value']

            type = variable_data['type'].replace('set(', 'list(')

            if not type.startswith('list(') and not type.startswith('optional(list(') and isinstance(default, list) and len(default) > 0:
                    self.logger.info(f"Defaults: '{default}' for variable: '{variable_name}' is inside a list, getting it out")
                    try:
                        default = default[0]
                    except IndexError as exc:
                        raise RuntimeError(f"failed to extract default from list: {default}") from exc
                
                    results[variable_name]['default_value'] = default
            
            if results[variable_name]['default_value'] == [None]:
                results[variable_name]['default_value'] = []

            # if default != None:
            #     type_open_parens = type.removesuffix(')')
            #
            #     if isinstance(default, str):
            #         results[variable_name]['type'] = f"{type_open_parens}, \"{default}\")".replace("'", '"').replace("\\", "\\\\").replace("${", "$${")
            #     else:
            #         results[variable_name]['type'] = f"{type_open_parens}, {json.dumps(default)})".replace("True", "true").replace("False", "false")
                
        self.log_results(results, 'Results after applying base variable data')

        return results

    def decode_type_param(self, type):
        if isinstance(type, list):
            self.logger.info(f"Parameter: {type} is inside a list, getting it out")
            type = type[0]

        try:
            return ')'.join(type.replace('${', 'optional(').replace("}'", ")'").rsplit('}', 1)).replace('{\'', '{\n').replace(', \'', '\n').replace('}', '\n}').replace('\'\n', '\n').replace('\': \'', ' = ').replace("'", "\"")
        except AttributeError as exc:
            raise RuntimeError(f"Failed to decode type: {type}") from exc
            

    def log_results(self, results, label='Results'):
        self.logger.info(f"[JSON] {label}:\n{json.dumps(results, indent=4, sort_keys=True)}")


    @classmethod
    def from_stdin(cls):
        inp = json.load(sys.stdin)
        return cls(**inp)


def main():
    cpmc = RemoteModuleConfig.from_stdin()
    result = {
        "merged_map": b64encode(json.dumps(cpmc.convert()).encode("utf-8")).decode("utf-8")
    }

    sys.stdout.write(json.dumps(result))


if __name__ == '__main__':
    main()
