/* Shared demo shell theme. Hosts opt in with data-selecto-demo-theme on <html>
 * or on this script. Explorer packages remain host-neutral. */
(() => {
  const root = document.documentElement;
  if (!root.hasAttribute("data-selecto-demo-theme") && !document.currentScript?.hasAttribute("data-selecto-demo-theme")) return;
  if (!root.hasAttribute("data-selecto-demo-theme")) root.setAttribute("data-selecto-demo-theme", "");
  if (window.selectoDemoTheme) return;
  const valid = (value) => ["system", "light", "dark"].includes(value);
  const key = "selecto-demo-theme";
  const media = window.matchMedia("(prefers-color-scheme: dark)");
  let saved;
  try { saved = localStorage.getItem(key) ?? localStorage.getItem("phx:theme"); } catch { /* Storage can be unavailable. */ }
  const requested = new URLSearchParams(location.search).get("theme");
  let preference = valid(requested) ? requested : valid(saved) ? saved : "system";
  let scheme;
  const scopes = ".selecto-explorer, .selecto-theme-scope";
  const syncScopes = () => {
    document.querySelectorAll(scopes).forEach((element) => {
      if (element.getAttribute("data-selecto-color-scheme") !== scheme) element.setAttribute("data-selecto-color-scheme", scheme);
    });
    document.querySelectorAll(".sx-theme-light, .sx-theme-dark").forEach((element) => {
      element.classList.toggle("sx-theme-light", scheme === "light");
      element.classList.toggle("sx-theme-dark", scheme === "dark");
    });
    const control = document.querySelector("#selecto-demo-theme");
    if (control) control.value = preference;
  };
  const apply = () => {
    scheme = preference === "system" ? (media.matches ? "dark" : "light") : preference;
    root.setAttribute("data-sc-color-scheme", scheme);
    root.setAttribute("data-selecto-color-scheme", scheme);
    root.setAttribute("data-theme", scheme);
    root.classList.toggle("dark", scheme === "dark");
    syncScopes();
    window.dispatchEvent(new CustomEvent("selecto-demo-theme-changed", { detail: { preference, scheme } }));
  };
  const choose = (value) => {
    if (!valid(value)) return;
    preference = value;
    try { localStorage.setItem(key, value); } catch { /* The current page still switches. */ }
    // Preserve a demo's explicit URL preview without letting it override a
    // subsequent choice on reload. Query/explorer state stays in place.
    const url = new URL(location.href);
    if (url.searchParams.has("theme")) {
      url.searchParams.set("theme", value);
      history.replaceState(history.state, "", url);
    }
    apply();
  };
  window.selectoDemoTheme = { choose, mount: () => start(), get preference() { return preference; }, get scheme() { return scheme; } };
  apply();
  // Phoenix's existing header buttons use this event. Keep them connected to
  // the same persisted preference as the explicit Appearance control.
  window.addEventListener("phx:set-theme", (event) => choose(event.target.dataset.phxTheme));
  media.addEventListener("change", () => { if (preference === "system") apply(); });
  window.addEventListener("storage", (event) => {
    if (event.key === key) { preference = valid(event.newValue) ? event.newValue : "system"; apply(); }
  });
  const mount = () => {
    if (!document.querySelector("#selecto-demo-theme")) {
      const bar = document.createElement("div");
      bar.className = "selecto-demo-theme-bar";
      const label = document.createElement("label");
      label.htmlFor = "selecto-demo-theme";
      label.textContent = "Appearance";
      const select = document.createElement("select");
      select.id = "selecto-demo-theme";
      select.setAttribute("aria-label", "Appearance");
      for (const value of ["system", "light", "dark"]) {
        const option = document.createElement("option");
        option.value = value;
        option.textContent = value === "system" ? "System" : value === "light" ? "Light" : "Dark";
        select.append(option);
      }
      select.addEventListener("change", () => choose(select.value));
      bar.append(label, select);
      document.body.prepend(bar);
    }
    syncScopes();
  };
  let started = false;
  const start = () => {
    if (started) return;
    started = true;
    new MutationObserver(() => {
      if (root.getAttribute("data-sc-color-scheme") !== scheme || root.getAttribute("data-selecto-color-scheme") !== scheme) apply();
    }).observe(root, { attributes: true, attributeFilter: ["data-sc-color-scheme", "data-selecto-color-scheme"] });
    mount();
    // Covers portals, HTMX/Turbo fragments and LiveView patches. Only update
    // attributes that differ, so our own changes cannot cause an observer loop.
    new MutationObserver(mount).observe(root, { childList: true, subtree: true, attributes: true, attributeFilter: ["data-selecto-color-scheme", "class"] });
  };
  if (root.getAttribute("data-selecto-demo-theme") === "manual") return;
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
