// Vercel requires a container to bind to PORT within 15 seconds. Documenso's
// production server has a longer module-load time, so this small local proxy
// accepts traffic immediately and forwards requests once Documenso is ready.
import http from 'node:http';

const port = Number(process.env.PORT || 80);
const upstreamPort = Number(process.env.DOCUMENSO_UPSTREAM_PORT || 3000);

http
  .createServer((request, response) => {
    const upstream = http.request(
      {
        hostname: '127.0.0.1',
        port: upstreamPort,
        method: request.method,
        path: request.url,
        headers: request.headers,
      },
      (upstreamResponse) => {
        response.writeHead(upstreamResponse.statusCode || 502, upstreamResponse.headers);
        upstreamResponse.pipe(response);
      },
    );

    upstream.on('error', () => {
      response.writeHead(503, { 'content-type': 'text/plain; charset=utf-8', 'retry-after': '5' });
      response.end('The signing service is starting. Please retry in a few seconds.');
    });

    request.pipe(upstream);
  })
  .listen(port, '0.0.0.0', () => {
    console.log(`Vercel readiness proxy listening on ${port}`);
  });
