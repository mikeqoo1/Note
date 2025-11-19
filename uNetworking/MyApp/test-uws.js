// test-uws.js
const uWS = require('@mike/uws-http3');

console.log('Node modules ABI =', process.versions.modules);

uWS.App()
  .get('/', (res, req) => {
    res.end('Hello from custom uWS HTTP/3 build!');
  })
  .listen(9001, (token) => {
    if (token) {
      console.log('✅ Listening on port 9001');
    } else {
      console.error('❌ Failed to listen on port 9001');
    }
  });
