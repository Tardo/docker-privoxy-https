// This is a basic example of a PAC
// Change <HERE_THE_PRIVOXY_IP:8118> with the ip/port of privoxy
// Maybe you will need change the internal network too to match it with your configuration
function FindProxyForURL(url, host) {
    if (isPlainHostName(host) || isInNet(host, "192.168.1.0", "255.255.255.0")) {
        return "DIRECT";
    } else if (url.startsWith("http:") || url.startsWith("https:")) {
        return "PROXY HERE_THE_PRIVOXY_IP:8118";
    }
    return "DIRECT";
}