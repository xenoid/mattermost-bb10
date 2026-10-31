#include <openssl/ssl.h>

/* Qt 4.8 only calls SSLv23_client_method. This server closes that handshake. */
const SSL_METHOD *SSLv23_client_method(void)
{
    return TLSv1_2_client_method();
}
