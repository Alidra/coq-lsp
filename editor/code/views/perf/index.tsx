// This is the script that is loaded by Coq's webview
import * as React from "react";
import { createRoot } from "react-dom/client";
import App from "./App";

const container = document.getElementById("root");
if (container) {
  const root = createRoot(container); // createRoot(container!) if you use TypeScript
  root.render(
    <React.StrictMode>
      <App />
    </React.StrictMode>
  );
}
