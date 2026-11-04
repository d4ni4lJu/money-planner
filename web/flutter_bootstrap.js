{{flutter_js}}
{{flutter_build_config}}

// Start the app, then remove the "Loading…" message.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const el = document.getElementById("loading");
    if (el) el.remove();
  },
});
