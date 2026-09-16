"use client";

// ローカルのトークン削除とCognitoセッションの破棄（/logout?logout_uri=...）を行う
import { redirectToLogout } from "../lib/cognito";

export default function LogoutButton() {
    return <button onClick={() => redirectToLogout()}>ログアウト</button>;
}
