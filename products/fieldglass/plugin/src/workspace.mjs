import { z } from 'zod';

export const action = z.enum(['status','draft','speak','reminder']);
export const draftText = z.string().max(480).refine(v => Buffer.byteLength(v) <= 480 && !/\p{Cc}/u.test(v));
export function workspaceLink(id, action, text) {
  if (action === 'status' ? text !== '' : text.trim() === '') return null;
  const params = new URLSearchParams({id,action,text});
  return 'fieldglass://workspace/v1?' + params.toString().replaceAll('+','%20');
}
