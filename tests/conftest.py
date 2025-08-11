# Copyright  Alexandre Díaz <dev@redneboa.es>
# License AGPL-3.0 or later (http://www.gnu.org/licenses/agpl).

import time
import requests
import pytest
from python_on_whales import DockerClient
import platform

PRIVOXY_PORT = "8118"
IMAGE_TAG_NAME = "test:docker-privoxy-https"
SUBNET = "172.20.0.0/16"
GATEWAY = "172.20.0.1"
IP_ADDRESS = "172.20.0.5"


def pytest_addoption(parser):
    parser.addoption("--no-cache", action="store_true", default=False)
    parser.addoption("--privoxy-version", action="store", default="4.0.0")


@pytest.fixture(scope="session")
def env_info(pytestconfig):
    no_cache = bool(pytestconfig.getoption("no_cache", False))
    privoxy_ver = pytestconfig.getoption("privoxy_version")
    return {
        "ip": IP_ADDRESS,
        "ports": {
            "privoxy": PRIVOXY_PORT,
        },
        "options": {
            "no_cache": no_cache,
            "privoxy_version": privoxy_ver,
        },
    }


@pytest.fixture(scope="session")
def docker_build(env_info):
    docker = DockerClient()
    docker.build(
        ".",
        build_args={
            "PRIVOXY_VERSION": env_info["options"]["privoxy_version"],
        },
        tags=IMAGE_TAG_NAME,
        cache=not env_info["options"]["no_cache"],
        target="runtime",
    )
    return docker


@pytest.fixture(scope="session")
def docker_privoxy(docker_build):
    container = None
    network = None
    try:
        if not docker_build.network.exists("pytest-privoxy-network"):
            network = docker_build.network.create(
                "pytest-privoxy-network",
                driver="bridge",
                subnet=SUBNET,
                gateway=GATEWAY,
            )
        container = docker_build.container.run(
            IMAGE_TAG_NAME,
            volumes=[
                ("pytest-privoxy", "/usr/local/etc/privoxy"),
            ],
            networks=["pytest-privoxy-network"],
            ip=IP_ADDRESS,
            envs={
                "ADBLOCK_URLS": "https://easylist-downloads.adblockplus.org/easylist.txt",
                "ADBLOCK_CSS_DOMAIN": IP_ADDRESS,
                "NGINX_SERVER_NAME": IP_ADDRESS,
            },
            name="privoxy-pytest",
            remove=True,
            detach=True,
        )
        time.sleep(20)  # Wait for service. FIXME: found a better way...
        docker_build.copy(
            ("privoxy-pytest", "/usr/local/etc/privoxy/CA/privoxy-ca-bundle.crt"),
            "./tests/privoxy-ca-bundle.crt",
        )
        yield container
    finally:
        if container:
            docker_build.container.kill(container)
            time.sleep(5)  # Wait for docker
        if network:
            docker_build.network.remove("pytest-privoxy-network")
        docker_build.volume.remove("pytest-privoxy")


@pytest.fixture(scope="session")
def make_request():
    def _run(url, use_privoxy_ca_bundle=True):
        return requests.get(
            url,
            proxies={
                "http": f"{IP_ADDRESS}:{PRIVOXY_PORT}",
                "https": f"{IP_ADDRESS}:{PRIVOXY_PORT}",
            },
            verify="./tests/privoxy-ca-bundle.crt" if use_privoxy_ca_bundle else None,
        )

    return _run


@pytest.fixture(scope="session")
def exec_privman():
    def _run(docker_container, *args):
        docker = DockerClient()
        return docker.container.execute(docker_container, ["privman"] + list(args))

    return _run
