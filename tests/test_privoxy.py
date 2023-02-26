# Copyright  Alexandre Díaz <dev@redneboa.es>
# License AGPL-3.0 or later (http://www.gnu.org/licenses/agpl).

import pytest
from requests.exceptions import SSLError


class TestPrivoxyContainer:

    def test_https(self, docker_privoxy, make_request):
        resp = make_request('https://google.com', docker_privoxy)
        assert resp.status_code == 200
        assert "google" in resp.text

    def test_http(self, docker_privoxy, make_request):
        resp = make_request('http://google.com', docker_privoxy)
        assert resp.status_code == 200
        assert "google" in resp.text

    def test_https_no_verify(self, docker_privoxy, make_request):
        with pytest.raises(SSLError):
            make_request('https://google.com', docker_privoxy, use_privoxy_ca_bundle=False)
