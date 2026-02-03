# Copyright  Alexandre Díaz <dev@redneboa.es>
# License AGPL-3.0 or later (http://www.gnu.org/licenses/agpl).

import time
import pytest
import requests
from requests.exceptions import SSLError, ConnectionError


class TestPrivoxyContainer:
    def _is_blocked_by_privoxy(self, response):
        return response.status_code == 403 and "Request blocked" in response.text

    def test_http(self, docker_privoxy, make_request):
        resp = make_request("http://google.com")
        assert resp.status_code == 200
        assert "google" in resp.text

    def test_https(self, docker_privoxy, make_request):
        resp = make_request("https://google.com")
        assert resp.status_code == 200
        assert "google" in resp.text

    def test_https_no_verify(self, docker_privoxy, make_request):
        with pytest.raises(SSLError):
            make_request("https://google.com", use_privoxy_ca_bundle=False)

    def test_http_adblock_filters(self, docker_privoxy, make_request):
        resp = make_request("http://googie-anaiytics.com")
        assert self._is_blocked_by_privoxy(resp) == True

    def test_https_adblock_filters(self, docker_privoxy, make_request):
        resp = make_request("https://googie-anaiytics.com")
        assert self._is_blocked_by_privoxy(resp) == True

    def test_http_no_adblock_filters(self):
        try:
            resp = requests.get("http://googie-anaiytics.com")
            assert self._is_blocked_by_privoxy(resp) == False
        except ConnectionError:
            pass  # 99% blocked by external software

    def test_https_no_adblock_filters(self):
        try:
            resp = requests.get("https://googie-anaiytics.com")
            assert self._is_blocked_by_privoxy(resp) == False
        except ConnectionError:
            pass  # 99% blocked by external software

    def test_http_adblock_blackhole(self, docker_privoxy, env_info):
        resp = requests.get(f"http://{env_info['ip']}/@blackhole")
        assert resp.status_code == 200
        mime_type = resp.headers.get("Content-Type")
        assert mime_type == "text/html"
        assert "adblock2privoxy" in resp.text
        resp = requests.get(f"http://{env_info['ip']}/notexists/ab2p.common.css")
        assert resp.status_code == 200
        mime_type = resp.headers.get("Content-Type")
        assert mime_type == "text/html"
        assert "adblock2privoxy" in resp.text

    def test_https_adblock_blackhole(self, docker_privoxy, env_info):
        resp = requests.get(
            f"https://{env_info['ip']}/@blackhole",
            verify="./tests/privoxy-ca-bundle.crt",
        )
        assert resp.status_code == 200
        mime_type = resp.headers.get("Content-Type")
        assert mime_type == "text/html"
        assert "adblock2privoxy" in resp.text
        resp = requests.get(
            f"https://{env_info['ip']}/notexists/ab2p.common.css",
            verify="./tests/privoxy-ca-bundle.crt",
        )
        assert resp.status_code == 200
        mime_type = resp.headers.get("Content-Type")
        assert mime_type == "text/html"
        assert "adblock2privoxy" in resp.text

    def test_http_adblock_css_filters(self, docker_privoxy, env_info):
        resp = requests.get(f"http://{env_info['ip']}/ab2p.common.css")
        assert resp.status_code == 200
        mime_type = resp.headers.get("Content-Type")
        assert mime_type == "text/css"

    def test_https_adblock_css_filters(self, docker_privoxy, env_info):
        resp = requests.get(
            f"https://{env_info['ip']}/ab2p.common.css",
            verify="./tests/privoxy-ca-bundle.crt",
        )
        assert resp.status_code == 200
        mime_type = resp.headers.get("Content-Type")
        assert mime_type == "text/css"

    def test_http_privman_blocklist(self, docker_privoxy, make_request, exec_privman):
        resp = exec_privman(docker_privoxy, "--add-blocklist", ".google.")
        assert "successfully" in resp
        time.sleep(3)
        resp = make_request("http://google.com")
        assert self._is_blocked_by_privoxy(resp) == True
        resp = exec_privman(docker_privoxy, "--remove-blocklist", ".google.")
        assert "successfully" in resp
        time.sleep(3)
        resp = make_request("http://google.com")
        assert resp.status_code == 200

    def test_https_privman_blocklist(self, docker_privoxy, make_request, exec_privman):
        resp = exec_privman(docker_privoxy, "--add-blocklist", ".google.")
        assert "successfully" in resp
        time.sleep(3)
        resp = make_request("https://google.com")
        assert self._is_blocked_by_privoxy(resp) == True
        resp = exec_privman(docker_privoxy, "--remove-blocklist", ".google.")
        assert "successfully" in resp
        time.sleep(3)
        resp = make_request("https://google.com")
        assert resp.status_code == 200

    def test_csp(self, docker_privoxy, make_request, env_info):
        resp = make_request("https://www.linkedin.com")
        assert resp.status_code == 200
        csp = resp.headers.get("Content-Security-Policy")
        assert env_info["ip"] in csp
