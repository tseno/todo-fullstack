import type { NextConfig } from "next";

// S3 + CloudFrontで配信するため静的エクスポートする（ビルド結果は out/ に出る）
const nextConfig: NextConfig = {
  output: "export",
};

export default nextConfig;
