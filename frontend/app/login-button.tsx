"use client";

// Cognito Hosted UIへ遷移するボタン（PKCE + stateは lib/cognito.ts 内で準備される）
import { redirectToLogin } from "../lib/cognito";

export default function LoginButton() {
    return <button onClick={() => redirectToLogin()}>ログイン</button>;
}
