#!/usr/bin/env python
#-*- coding: utf-8 -*-

"""
Script for parsing and concatenating StackScripts

Usage example:

prepare.py "131 - Stack - Security, PostgreSQL, MySQL, MongoDB, Apache, Django.sh" @settings.txt
"""

import argparse
import glob
import os
import re
import sys
from xml.etree.ElementTree import fromstring


class ArgParser(argparse.ArgumentParser):

    def convert_arg_line_to_args(self, arg_line):
        parts = arg_line.split(None, 1)
        if len(parts)  == 2:
            return [p.strip() for p in parts]
        return []


def get_udfs(content):
    udf_re = re.compile("^\s*#\s*(<UDF.+/>)", re.IGNORECASE | re.MULTILINE)
    return udf_re.findall(content)


def parse_param(udf):
    element = fromstring(udf)
    choices = element.get("oneof")
    if choices:
        choices = choices.split(",")
    return {
        'name': element.get("name"),
        'label': element.get("label"),
        'choices': choices,
        'default': element.get("default"),
        'example': element.get("example")
    }


def build_argparser(content):
    parser = ArgParser(
        description='Process StackScript file params.',
        fromfile_prefix_chars='@',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        epilog="Use @settings.txt as param to read configuration from settings file."
    )
    parser.add_argument('script', metavar='SCRIPT', nargs=1, help='main script')

    for udf in get_udfs(content):
        param = parse_param(udf)
        help = param["example"] or ""
        default = param["default"]
        required = param["default"] is None
        parser.add_argument(
            '--%s' % param["name"], dest=param["name"].upper(),
            action='store', default=default, choices=param["choices"] or None,
            required=required, help=help
        )
    return parser


def lookup_script(script_id):
    try:
        return glob.glob("%s - *.sh" % script_id)[0]
    except IndexError:
        raise ValueError("Script for given id does not exist: %s." % script_id)


def get_content(script_id):
    with open(lookup_script(script_id)) as fp:
        return fp.read()


def expand_script(content, mode="source"):
    assert mode in ["source", "include"]
    re_source = re.compile("""<ssinclude\s+StackScriptID\s*=\s*"(\d+)"\s*>""")
    re_include = re.compile("""^(\s*source\s+<ssinclude\s+StackScriptID\s*=\s*["'](\d+)[".]>.*)$""", re.MULTILINE)
    if mode == "source":
        content = re_source.sub(
            lambda x: '"%s"' % lookup_script(x.group(1)),
            content
        )
    else:
        content = re_include.sub(
            lambda x: '\n#==> Content of %s ==>>\n%s\n#<<== end of %s <=\n' %
                (x.group(2), get_content(x.group(2)), x.group(2)),
            content
        )
    return content


def add_variables(content, args):
    # Add script variables
    variables = "%s\n" % "\n".join(
        '%s="%s"' % (k,v) for k,v in sorted(args.__dict__.items()) if k.isupper()
    )
    lines = iter(content.splitlines())
    content = []
    for line in lines:
        if line.startswith("#") or not line.strip():
            content.append(line)
        else:
            content.append(variables)
            content.append(line)
            content.extend(lines)
            break
    return "\n".join(content)


def main(stack_script):

    if stack_script:
        with open(stack_script) as fp:
            content = fp.read()

        parser = build_argparser(content)
        args = parser.parse_args()

        content = expand_script(content, mode="include")
        content = add_variables(content, args)

        print content


if __name__ == "__main__":
    if len(sys.argv) < 2 or not os.path.exists(sys.argv[1]):
        print "First argument must be a valid script name"
    main(sys.argv[1])
