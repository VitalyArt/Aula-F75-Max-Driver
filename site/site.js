(() => {
  "use strict";
  const translations = window.aulaTranslations;
  const storageKey = "aula-docs-language";
  const releasePage = "https://github.com/VitalyArt/Aula-F75-Max-Driver/releases/latest";
  const api = "https://api.github.com/repos/VitalyArt/Aula-F75-Max-Driver/releases/latest";
  let language = "en";
  let assets = [];
  let releaseVersion = "";
  const resolve = value => Object.hasOwn(translations, value) ? value : "en";
  try { language = resolve(localStorage.getItem(storageKey)); } catch { /* Storage may be unavailable. */ }
  const select = document.querySelector("#language-select");
  const dictionary = () => translations[language];

  function validAssets(platform) {
    const extension = { macos: ".dmg", linux: ".deb", android: ".apk" }[platform];
    return assets.filter(asset => {
      if (!asset || typeof asset.name !== "string" || !asset.name.toLowerCase().endsWith(extension)) return false;
      try {
        const url = new URL(asset.browser_download_url);
        return url.protocol === "https:" && url.hostname === "github.com" &&
          url.pathname.startsWith("/VitalyArt/Aula-F75-Max-Driver/releases/download/");
      } catch { return false; }
    });
  }

  function renderDownloads() {
    document.querySelectorAll("[data-platform]").forEach(container => {
      const platform = container.dataset.platform;
      const candidates = validAssets(platform);
      // A single desktop/mobile package needs no additional choice. Linux packages
      // remain explicit when a release offers more than one architecture.
      const choices = platform === "linux" ? candidates : candidates.slice(0, 1);
      const info = container.querySelector(".release-info");
      info.hidden = !releaseVersion || choices.length === 0;
      const format = { macos: "DMG", linux: "DEB", android: "APK" }[platform];
      info.textContent = info.hidden ? "" : `${dictionary().version} ${releaseVersion} · ${format}`;
      const options = container.querySelector(".download-options");
      options.replaceChildren();
      const key = {macos: "downloadMac", linux: "downloadLinux", android: "downloadAndroid"}[platform];
      (choices.length ? choices : [null]).forEach(asset => {
        const wrapper = document.createElement("div");
        wrapper.className = "asset-choice";
        const link = document.createElement("a");
        link.className = "button";
        link.href = asset ? asset.browser_download_url : releasePage;
        link.textContent = dictionary()[asset ? key : "downloadPage"];
        if (asset && platform === "linux") {
          const architecture = asset.name.match(/_([^_]+)\.deb$/i)?.[1];
          const label = document.createElement("span");
          label.className = "architecture-label";
          const family = { amd64: "Intel / AMD", x86_64: "Intel / AMD", arm64: "ARM", aarch64: "ARM" }[architecture?.toLowerCase()];
          const description = family ? `${family} (${architecture})` : architecture || asset.name;
          label.textContent = `${dictionary().architecture}: ${description}`;
          wrapper.append(label);
          link.setAttribute("aria-label", `${dictionary()[key]} — ${description}`);
        }
        wrapper.append(link);
        options.append(wrapper);
      });
      container.querySelector(".download-hint").hidden = choices.length > 0;
    });
  }

  function applyLanguage(value) {
    language = resolve(value);
    document.documentElement.lang = language;
    document.querySelectorAll("[data-i18n]").forEach(element => {
      element.textContent = dictionary()[element.dataset.i18n];
    });
    ["alt", "aria-label"].forEach(attribute => {
      const data = attribute === "alt" ? "i18nAlt" : "i18nAria";
      document.querySelectorAll(attribute === "alt" ? "[data-i18n-alt]" : "[data-i18n-aria]").forEach(element => {
        element.setAttribute(attribute, dictionary()[element.dataset[data]]);
      });
    });
    document.querySelectorAll('meta[name="description"], meta[property="og:description"]').forEach(meta => {
      meta.content = dictionary().meta;
    });
    document.querySelectorAll(".copy-status").forEach(status => { status.textContent = ""; });
    if (select) select.value = language;
    renderDownloads();
  }
  select?.addEventListener("change", () => {
    try { localStorage.setItem(storageKey, select.value); } catch { /* Keep the current selection usable. */ }
    applyLanguage(select.value);
  });
  document.querySelectorAll(".copy-button").forEach(button => {
    button.hidden = false;
    button.addEventListener("click", async () => {
      const box = button.closest(".commands");
      try {
        await navigator.clipboard.writeText(box.querySelector("code").textContent);
        box.querySelector(".copy-status").textContent = dictionary().copied;
      } catch {
        box.querySelector(".copy-status").textContent = dictionary().copyFailed;
      }
    });
  });
  applyLanguage(language);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  fetch(api, { signal: controller.signal, headers: { Accept: "application/vnd.github+json" } })
    .then(response => {
      if (!response.ok) throw new Error("Release unavailable");
      return response.json();
    })
    .then(release => {
      assets = Array.isArray(release.assets) ? release.assets : [];
      releaseVersion = typeof release.tag_name === "string" ? release.tag_name.replace(/^v(?=\d)/, "") : "";
      renderDownloads();
    })
    .catch(() => { /* The visible release-page links remain available. */ })
    .finally(() => clearTimeout(timeout));
})();
