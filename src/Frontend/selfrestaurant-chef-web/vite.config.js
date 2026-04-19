import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
export default defineConfig(function (_a) {
    var mode = _a.mode;
    var env = loadEnv(mode, ".", "");
    var gatewayUrl = env.VITE_GATEWAY_URL || "http://localhost:5100";
    return {
        plugins: [react()],
        base: "/app/chef/",
        server: {
            port: 5174,
            strictPort: true,
            proxy: {
                "/api": {
                    target: gatewayUrl,
                    changeOrigin: true,
                },
            },
        },
        preview: {
            port: 4174,
        },
    };
});
