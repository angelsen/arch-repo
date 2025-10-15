const originalFetch = window.fetch;
window.fetch = async (...args) => {
  console.log('🔵 REQ:', args[0], args[1]);
  const res = await originalFetch(...args);
  const clone = res.clone();
  const body = await clone.text();
  console.log('🟢 RES:', args[0], res.status, body);
  return res;
};
