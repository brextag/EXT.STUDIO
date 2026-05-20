# 🚀 Gemini AI Roblox Studio Assistant

A highly aesthetic, native-themed Roblox Studio plugin that connects directly to the official **Google Gemini API** (`gemini-2.5-flash`). It interprets your natural language commands and generates/executes Luau scripts directly in the Studio environment to build, modify, or analyze your game dynamically.

---

## ✨ Features

- **💡 Dynamic Natural Language commands**: "Make a ring of 10 golden spheres", "Find all Anchored parts and paint them Neon Blue", "Create a basic obby stage", etc.
- **🎨 Native Studio Theme Sync**: The UI dynamically updates its background, text, borders, buttons, and input fields to match Roblox Studio's Dark or Light theme.
- **🔒 Secure Local Storage**: Your Gemini API key is saved safely on your own machine using Roblox's `Plugin:SetSetting` API. It is never uploaded anywhere except to Google's official Gemini endpoint.
- **⚡ Dual Execution Modes**:
  1. **Run Code Directly**: Generates and compiles the Luau code, running it immediately via `loadstring`.
  2. **Create Script Instance**: Generates the code and writes it to a new `Script` in `Workspace` so you can review, tweak, and test it manually.
- **🪵 Built-in Console**: An interactive scrollable status log showing compilation errors, network latency, and API feedback.

---

## 🛠️ Installation & Setup

Follow these simple steps to load the plugin into Roblox Studio:

### 1. Enable HTTP Requests in Roblox Studio
Since the plugin needs to connect to the Gemini API, you must allow HTTP requests in your active game:
1. Open your place in **Roblox Studio**.
2. Click on **Home > Game Settings** (if the game is not published, publish it first).
3. Select the **Security** tab.
4. Toggle **Allow HTTP Requests** to **ON**.
5. Click **Save**.

### 2. Install the Plugin
1. In your **Explorer** window, create a new `Script` under **ServerScriptService** (or anywhere you like).
2. Rename it to `GeminiAssistant`.
3. Open `plugin.lua` from this project, copy its entire contents, and paste it into your new `GeminiAssistant` script.
4. Right-click on the `GeminiAssistant` script in the Explorer window.
5. Select **Save as Local Plugin...** from the context menu.
6. Save the file (e.g., `GeminiAssistant.local.rbxmx`) in the default directory Roblox suggests.
7. You should see a new dockable widget titled **Gemini AI Assistant** pop up, and a new ribbon icon added to your **Plugins** tab! You can delete the temporary script you created.

### 3. Setup your API Key
1. Go to [Google AI Studio](https://aistudio.google.com/) and click **Get API Key** to obtain a free Gemini API key.
2. In the plugin window, paste your key into the **Enter Gemini API Key** input field.
3. Click **Save API Key**.
4. The key is now securely stored in your local Roblox settings and masked (`••••••••••••`).

---

## 🎯 Sample Prompts to Try

Here are some neat natural language commands you can try typing in the assistant box:

- **Generative Building**:
  > *"Create a spiral staircase of 25 steps rotating upwards around the Y axis. Each step should be a smooth plastic block colored pastel blue."*
- **Aesthetic Modifications**:
  > *"Find every Part in the Workspace. If it is Anchored, paint it neon green. If it is Unanchored, paint it marble red."*
- **Instancing Scripted Items**:
  > *"Create a glowing red sphere in Workspace. Add a PointLight inside it and a script that slowly rotates its color between red, green, and blue over time."*
- **Scene Cleanup**:
  > *"Find all instances named 'TemporaryBlock' in the Workspace and destroy them."*
