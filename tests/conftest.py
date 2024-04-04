 # Copyright  Alexandre Díaz <dev@redneboa.es>
# License AGPL-3.0 or later (http://www.gnu.org/licenses/agpl).

import time
import requests
import pytest
from python_on_whales import DockerClient

PRIVOXY_PORT = "8118"


def pytest_addoption(parser):
    parser.addoption('--no-cache', action='store_true', default=False)
    parser.addoption('--privoxy-version', action='store', default="3.0.34")

@pytest.fixture(scope='session')
def docker_build(pytestconfig):
    docker = DockerClient()
    no_cache = bool(pytestconfig.getoption('no_cache', False))
    privoxy_ver = pytestconfig.getoption('privoxy_version')
    docker.build(
        ".",
        build_args={
            'PRIVOXY_VERSION': privoxy_ver,
        },
        tags="test:docker-privoxy-https",
        cache=not no_cache,
    )
    return docker

@pytest.fixture(scope='session')
def docker_privoxy(docker_build):
    container = None
    try: 
        container = docker_build.container.run(
            "test:docker-privoxy-https",
            volumes=[
                ("pytest-privoxy", "/usr/local/etc/privoxy"),
            ],
            publish=[
                (PRIVOXY_PORT, PRIVOXY_PORT)
            ],
            envs={
                "ADBLOCK_URLS": "https://easylist.to/easylist/easylist.txt",
                "ADBLOCK_FILTERS": '"attribute_global_name attribute_global_exact attribute_global_contain attribute_global_startswith attribute_global_endswith class_global id_global"',
            },
            name="privoxy-pytest",
            remove=True,
            detach=True,
        )
        time.sleep(5)   # Wait for service
        docker_build.copy(("privoxy-pytest", "/usr/local/etc/privoxy/CA/privoxy-ca-bundle.crt"), "./tests/privoxy-ca-bundle.crt")
        yield container
    finally:
        if container:
            docker_build.container.kill(container)
            time.sleep(5)    # Wait for docker
        docker_build.volume.remove("pytest-privoxy")

@pytest.fixture(scope='session')
def make_request():
    def _run(url, docker_container, use_privoxy_ca_bundle=True):
        proxy_ip = docker_container.network_settings.ip_address
        return requests.get(url, proxies={
            'http': f'{proxy_ip}:{PRIVOXY_PORT}',
            'https': f'{proxy_ip}:{PRIVOXY_PORT}',
        }, verify="./tests/privoxy-ca-bundle.crt" if use_privoxy_ca_bundle else None)
    return _run

@pytest.fixture(scope='session')
def exec_privman():
    def _run(docker_container, *args):
        docker = DockerClient()
        return docker.container.execute(
            docker_container,
            ['privman'] + list(args)
        )
    return _run
