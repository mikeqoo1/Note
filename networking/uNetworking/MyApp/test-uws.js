const uWS = require('@mike/uws-http3');

console.log('Node modules ABI =', process.versions.modules);
const port = 9001;

const app = uWS.H3App({
  key_file_name: 'misc/key.pem',
  cert_file_name: 'misc/cert.pem',
  passphrase: '1234'
});

console.log('H3App created:', typeof app, Object.keys(app));

app.get('/*', (res, req) => {
  res.end('H3llo World!');
});

app.listen(port, (token) => {
  if (token) {
    console.log('✅ H3 server listening on UDP port', port);
  } else {
    console.log('❌ Failed to listen on port', port);
  }
});
