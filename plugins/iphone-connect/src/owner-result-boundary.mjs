// A host-provided lookup is not a device attestation. Validate its public
// projection again before exposing it through either MCP transport.
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const STATES = new Set([
  'awaiting-manual-delivery', 'delivery-prepared-not-sent', 'not-sent',
  'outcome-unknown', 'awaiting-key-authenticated-receipt',
  'receipt-key-authenticated', 'cancelled-local', 'expired-before-send'
]);
const KEYS = ['requestId', 'state', 'receiptKeyAuthenticated', 'deviceReceipt',
  'actionExecuted', 'ownerApproved', 'iPhoneConnected'];
const invalid = () => { throw Error('invalidOwnerTaskResult'); };

export function validateOwnerTaskResult(requestId, value) {
  if (typeof requestId !== 'string' || !UUID.test(requestId)) invalid();
  if (value === null) return null;
  if (!value || typeof value !== 'object' || Array.isArray(value)
      || Object.keys(value).length !== KEYS.length
      || !KEYS.every(key => Object.hasOwn(value, key))) invalid();
  const { requestId: returnedId, state, receiptKeyAuthenticated, deviceReceipt,
    actionExecuted, ownerApproved, iPhoneConnected } = value;
  const authenticated = state === 'receipt-key-authenticated';
  if (returnedId !== requestId || !STATES.has(state)
      || receiptKeyAuthenticated !== authenticated
      || deviceReceipt !== (authenticated ? 'key-authenticated-not-device-attested' : 'none')
      || actionExecuted !== false || ownerApproved !== false
      || iPhoneConnected !== 'not-checked') invalid();
  return Object.freeze({ requestId, state, receiptKeyAuthenticated, deviceReceipt,
    actionExecuted, ownerApproved, iPhoneConnected });
}
