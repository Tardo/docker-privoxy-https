#!/usr/bin/python
# Copyright  Alexandre Díaz <dev@redneboa.es>
# Privoxy Manager

import os
import argparse
import subprocess
import urllib.request

BASE_LIB_DIR = '/var/lib/privoxy'
BASE_DIR = '/usr/local/etc/privoxy'
BASEDIR_CA = os.path.join(BASE_DIR, 'CA')
BASEDIR_RULES = os.path.join(BASE_DIR, 'privman-rules')
ADBLOCK_DYN_FILE = os.path.join(BASE_LIB_DIR, 'adblock-dyn.conf')

RULES = {
    'WHITELIST': "{ -block -filter }",
    'SOFT_WHITELIST': "{ allow-ads }",
    'BLOCKLIST': "{ +block }",
}


def print_log(section, msg):
    print(f"[privman][{section}] {msg}")

def update_trusted_ca(forced=False):
    trusted_ca_file = os.path.join(BASEDIR_CA, 'trustedCAs.pem')
    if not os.path.isfile(trusted_ca_file) or forced:
        urllib.request.urlretrieve('https://curl.se/ca/cacert.pem', trusted_ca_file)
        print_log("Trusted CA", f"File updated successfully in '{trusted_ca_file}'") 
    else:
        print_log("Trusted CA", "Nothing to do. The file already exists.")

def generate_crt_bundle(subj, forced=False):
    ca_bundle_file = os.path.join(BASEDIR_CA, 'privoxy-ca-bundle.crt')
    ca_key_file = os.path.join(BASEDIR_CA, 'cakey.pem')
    if not os.path.isfile(ca_bundle_file) or forced:
        os.system(f"openssl ecparam -out {ca_key_file} -name secp384r1 -genkey")
        os.system(
            'openssl req -new -x509 '
            f'-key {ca_key_file} -sha384 -days 3650 '
            f'-out {ca_bundle_file} '
            f'-subj "{subj}" '
            '-addext "basicConstraints=critical,CA:TRUE" '
            '-addext "keyUsage=critical,keyCertSign,cRLSign" '
            '-addext "subjectKeyIdentifier=hash"'
        )
        print_log("CRT Bundle", f"Generated successfully in '{ca_bundle_file}'") 
    else:
        print_log("CRT Bundle", "Nothing to do. The file already exists.")

def update_adblock_filters():
    adblock_filters = " ".join(map(lambda x: f'"{x}"', os.environ.get("ADBLOCK_FILTERS", "").split(" ")))
    adblock_urls = " ".join(map(lambda x: f'"{x}"', os.environ.get("ADBLOCK_URLS", "").split(" ")))
    lines = [f"URLS=({adblock_urls})", f"\nFILTERS=({adblock_filters})"]
    with open(ADBLOCK_DYN_FILE, 'w') as f:
        f.writelines(lines)
    subprocess.run(["privoxy-blocklist", "-c", "/var/lib/privoxy/privoxy-blocklist.conf"])
    return True

def _get_section_index(rules, section):
    for index, rule in enumerate(rules):
        if rule.strip() == section:
            return index
    return -1

def _get_url_rule_index(rules, start, url):
    for index, rule in enumerate(rules[start:], start):
        print('IT: ', start, '----', index, ' --- ', rule)
        if rule.strip() == url:
            return index
        if rule.startswith("{"):
            break
    return -1

def _append_to(filename, section_name, url):
    rules = []
    with open(filename, 'r') as f:
        rules = f.readlines()
    need_write = False
    rule_section_index = _get_section_index(rules, section_name)
    if rule_section_index == -1:
        rules.append(f"{section_name}\n")
        rules.append(f"{url}\n")
        need_write = True
    else:
        start_index = rule_section_index + 1
        rule_line_index = _get_url_rule_index(rules, start_index, url)
        if rule_line_index == -1:
            rules.insert(start_index + 1, f"{url}\n")
            need_write = True
    if need_write:
        with open(filename, 'w') as f:
            f.writelines(rules)
    return need_write

def _remove_from(filename, section_name, url):
    rules = []
    with open(filename, 'r') as f:
        rules = f.readlines()
    need_write = False
    rule_section_index = _get_section_index(rules, section_name)
    if rule_section_index != -1:
        start_index = rule_section_index + 1
        rule_line_index = _get_url_rule_index(rules, start_index, url)
        if rule_line_index != -1:
            rules.pop(rule_line_index)
            need_write = True
    if need_write:
        with open(filename, 'w') as f:
            f.writelines(rules)
    return need_write

def restart_privoxy():
    os.system("kill -HUP `cat /tmp/supervisord_privoxy.pid`")
    print_log("Privoxy", "Restarted successfully")

def add_whitelist(urls, soft_mode=False):
    user_action_file = os.path.join(BASEDIR_RULES, 'user.action')
    has_changes = False
    for url in urls:
        res = _append_to(user_action_file, RULES['SOFT_WHITELIST'] if soft_mode else RULES['WHITELIST'], url)
        if res:
            print_log("Soft-Whitelist" if soft_mode else "Whitelist", f"Successfully added the url '{url}'")
            has_changes = True
        else:
            print_log("Soft-Whitelist" if soft_mode else "Whitelist", f"The url '{url}' already exists")
    return has_changes

def remove_whitelist(urls):
    user_action_file = os.path.join(BASEDIR_RULES, 'user.action')
    has_changes = False
    for url in urls:
        res = _remove_from(user_action_file, RULES['WHITELIST'], url)
        if res:
            print_log("Whitelist", f"URL '{url}' removed successfully")
            has_changes = True
        else:
            print_log("Whitelist", f"The url '{url}' already not present")
    return has_changes

def add_blocklist(urls):
    user_action_file = os.path.join(BASEDIR_RULES, 'user.action')
    has_changes = False
    for url in urls:
        res = _append_to(user_action_file, RULES['BLOCKLIST'], url)
        if res:
            print_log("Blocklist", f"URL '{url}' added successfully")
            has_changes = True
        else:
            print_log("Blocklist", f"The url '{url}' already exists")
    return has_changes
    
def remove_blocklist(urls):
    user_action_file = os.path.join(BASEDIR_RULES, 'user.action')
    has_changes = False
    for url in urls:
        res = _remove_from(user_action_file, RULES['BLOCKLIST'], url)
        if res:
            print_log("Blocklist", f"URL '{url}' removed successfully")
            has_changes = True
        else:
            print_log("Blocklist", f"The url '{url}' already not present")
    return has_changes

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Privoxy Manager',
        add_help=True)
    parser.add_argument(
        '--init',
        help='Initialize the privoxy environment',
        action='store_true',
        default=False)
    parser.add_argument(
        '--restart',
        help='Restart privoxy',
        action='store_true',
        default=False)
    parser.add_argument(
        '--update-trusted-ca',
        help='Update Trusted CA',
        action='store_true',
        default=False)
    parser.add_argument(
        '--regenerate-crt-bundle',
        help='Regenerate the .crt bundle',
        action='store_true',
        default=False)
    parser.add_argument(
        '--crt-bundle-subj',
        type=str,
        nargs=1,
        help='Generate the .crt bundle',
        default="/C=ES/ST=Madrid/L=Madrid/O=DockerPrivoxy Security/OU=PROXY Department/CN=privoxy.proxy")
    parser.add_argument(
        '--update-adblock-filters',
        help='Update Adblock Filters',
        action='store_true',
        default=False)
    parser.add_argument(
        '--add-whitelist',
        type=str,
        action="extend", 
        nargs="+",
        help='Add URL to the whitelist')
    parser.add_argument(
        '--add-soft-whitelist',
        type=str,
        action="extend", 
        nargs="+",
        help='Add URL to the soft-whitelist')
    parser.add_argument(
        '--remove-whitelist',
        type=str,
        action="extend", 
        nargs="+",
        help='Remove URL from the whitelist')
    parser.add_argument(
        '--add-blocklist',
        '--add-blacklist',
        type=str,
        action="extend", 
        nargs="+",
        help='Add URL to the blocklist')
    parser.add_argument(
        '--remove-blocklist',
        '--remove-blacklist',
        type=str,
        action="extend", 
        nargs="+",
        help='Remove URL from the blocklist')
    args = parser.parse_args()
    need_restart = False

    if args.init:
        update_trusted_ca()
        update_adblock_filters()
        generate_crt_bundle(args.crt_bundle_subj)
    if args.update_trusted_ca:
        need_restart = update_trusted_ca(forced=True)
    if args.regenerate_crt_bundle:
        need_restart = generate_crt_bundle(args.crt_bundle_subj, forced=True)
    if args.update_adblock_filters:
        need_restart = update_adblock_filters()
    if args.add_whitelist:
        need_restart = add_whitelist(args.add_whitelist)
    if args.add_soft_whitelist:
        need_restart = add_whitelist(args.add_whitelist, soft_mode=True)
    if args.remove_whitelist:
        need_restart = remove_whitelist(args.remove_whitelist)
    if args.add_blocklist:
        need_restart = add_blocklist(args.add_blocklist)
    if args.remove_blocklist:
        need_restart = remove_blocklist(args.remove_blocklist)
    if args.restart or need_restart:
        restart_privoxy()
