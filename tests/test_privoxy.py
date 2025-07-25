# Copyright  Alexandre Díaz <dev@redneboa.es>
# License AGPL-3.0 or later (http://www.gnu.org/licenses/agpl).

import time
import pytest
from requests.exceptions import SSLError


class TestPrivoxyContainer:
    def _is_blocked_by_privoxy(self, response):
        return response.status_code == 403 and "Request blocked" in response.text

    def test_http(self, docker_privoxy, make_request):
        resp = make_request('http://google.com', docker_privoxy)
        assert resp.status_code == 200
        assert "google" in resp.text

    def test_https(self, docker_privoxy, make_request):
        resp = make_request('https://google.com', docker_privoxy)
        assert resp.status_code == 200
        assert "google" in resp.text

    def test_https_no_verify(self, docker_privoxy, make_request):
        with pytest.raises(SSLError):
            make_request('https://google.com', docker_privoxy, use_privoxy_ca_bundle=False)

    def test_blocklist(self, docker_privoxy, make_request, exec_privman):
        resp = exec_privman(docker_privoxy, "--add-blocklist", ".google.")
        assert "successfully" in resp
        time.sleep(3)
        resp = make_request('http://google.com', docker_privoxy)
        assert self._is_blocked_by_privoxy(resp) == True
        resp = exec_privman(docker_privoxy, "--remove-blocklist", ".google.")
        assert "successfully" in resp
        time.sleep(3)
        resp = make_request('https://google.com', docker_privoxy)
        assert resp.status_code == 200

    def test_adblock_filters(self, docker_privoxy, make_request):
        resp = make_request('http://google.com/www/ad/test', docker_privoxy)
        assert self._is_blocked_by_privoxy(resp) == True