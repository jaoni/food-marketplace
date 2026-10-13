import { createApp } from "./app.ts";
import { config } from "./config.ts";

createApp().listen(config.port, () => {
  console.log(`Server running on http://localhost:${config.port}`);
});
