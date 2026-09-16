// Cognito Hosted UI とのやり取りをまとめたモジュール。
// 値はビルド時に NEXT_PUBLIC_* 環境変数から注入される（frontend/.env.local を参照）
const COGNITO_DOMAIN = process.env.NEXT_PUBLIC_COGNITO_DOMAIN ?? "";
const COGNITO_CLIENT_ID = process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID ?? "";

// base64url エンコード（PKCEのチャレンジ生成で使う。URLに埋め込めるよう + / = を置き換える）
function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function randomString(length: number): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";
  const values = crypto.getRandomValues(new Uint8Array(length));
  return Array.from(values, (v) => chars[v % chars.length]).join("");
}

// PKCE: code_verifier のSHA-256ハッシュをチャレンジとしてCognitoに渡す
async function createCodeChallenge(verifier: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier));
  return base64UrlEncode(new Uint8Array(digest));
}

function isConfigured(): boolean {
  if (COGNITO_DOMAIN === "" || COGNITO_CLIENT_ID === "") {
    console.error("NEXT_PUBLIC_COGNITO_DOMAIN / NEXT_PUBLIC_COGNITO_CLIENT_ID が未設定です");
    return false;
  }
  return true;
}

// ログイン: PKCE用のverifierとstateを保存してからCognitoのログイン画面へ遷移する
export async function redirectToLogin(): Promise<void> {
  if (!isConfigured()) return;

  const verifier = randomString(64);
  const state = randomString(16);
  sessionStorage.setItem("code_verifier", verifier);
  sessionStorage.setItem("oauth_state", state);

  const challenge = await createCodeChallenge(verifier);
  const params = new URLSearchParams({
    client_id: COGNITO_CLIENT_ID,
    response_type: "code",
    scope: "openid email profile",
    redirect_uri: window.location.origin,
    code_challenge: challenge,
    code_challenge_method: "S256",
    state,
  });
  window.location.href = `https://${COGNITO_DOMAIN}/login?${params}`;
}

// コールバック処理: 認可コードをアクセストークンに交換してlocalStorageへ保存する
export async function exchangeCodeForToken(code: string, state: string): Promise<string | null> {
  if (!isConfigured()) return null;

  // stateとverifierは読んだ時点で消費する。
  // 認可コードは1回しか交換できないため、React StrictModeなどで
  // この関数が二重に呼ばれても、2回目はここで静かに止まるようになる
  const storedState = sessionStorage.getItem("oauth_state");
  const verifier = sessionStorage.getItem("code_verifier");
  sessionStorage.removeItem("oauth_state");
  sessionStorage.removeItem("code_verifier");

  if (verifier === null || storedState === null) return null;

  // stateが自分が発行したものと一致しない場合は不正なリダイレクトの可能性があるため中止（CSRF対策）
  if (storedState !== state) {
    console.error("stateが一致しないためトークン交換を中止しました");
    return null;
  }

  const res = await fetch(`https://${COGNITO_DOMAIN}/oauth2/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      client_id: COGNITO_CLIENT_ID,
      code,
      redirect_uri: window.location.origin,
      code_verifier: verifier,
    }),
  });
  if (!res.ok) {
    console.error("トークン交換に失敗しました", await res.text());
    return null;
  }
  const data = await res.json();
  localStorage.setItem("access_token", data.access_token);
  return data.access_token as string;
}

// ログアウト: 保存したトークンを消し、Cognito側のセッションも破棄してトップページへ戻る
export function redirectToLogout(): void {
  localStorage.removeItem("access_token");
  if (!isConfigured()) return;

  // Hosted UIの /logout が要求するのは logout_uri パラメータ
  const params = new URLSearchParams({
    client_id: COGNITO_CLIENT_ID,
    logout_uri: window.location.origin,
  });
  window.location.href = `https://${COGNITO_DOMAIN}/logout?${params}`;
}
