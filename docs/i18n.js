(() => {
  const storageKey = "shenghai-language";
  const normalizeLanguage = value => String(value || "").toLowerCase().startsWith("zh") ? "zh-Hant" : "en";

  function getPreferredLanguage() {
    const saved = localStorage.getItem(storageKey);
    if (saved) return normalizeLanguage(saved);
    const languages = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language];
    return normalizeLanguage(languages[0]);
  }

  function translateElement(element, language) {
    const key = language === "zh-Hant" ? "zh" : "en";
    const text = element.dataset[key];
    if (text !== undefined) element.textContent = text;

    const aria = element.dataset[`aria${key === "zh" ? "Zh" : "En"}`];
    if (aria !== undefined) element.setAttribute("aria-label", aria);
  }

  function applyLanguage(language) {
    const normalized = normalizeLanguage(language);
    localStorage.setItem(storageKey, normalized);
    document.documentElement.lang = normalized;

    document.querySelectorAll("[data-zh][data-en]").forEach(element => translateElement(element, normalized));
    document.querySelectorAll("[data-lang-button]").forEach(button => {
      const active = button.dataset.langButton === normalized;
      button.setAttribute("aria-pressed", String(active));
      button.classList.toggle("active", active);
    });

    const title = document.documentElement.dataset[normalized === "zh-Hant" ? "titleZh" : "titleEn"];
    if (title) document.title = title;

    const description = document.querySelector("meta[name='description']");
    if (description) {
      const descriptionText = description.dataset[normalized === "zh-Hant" ? "zh" : "en"];
      if (descriptionText) description.setAttribute("content", descriptionText);
    }

    window.dispatchEvent(new CustomEvent("shenghai:languagechange", { detail: { language: normalized } }));
  }

  function initLanguageSwitcher() {
    document.querySelectorAll("[data-lang-button]").forEach(button => {
      button.addEventListener("click", () => applyLanguage(button.dataset.langButton));
    });
    applyLanguage(getPreferredLanguage());
  }

  window.shenghaiI18n = {
    getLanguage: () => normalizeLanguage(localStorage.getItem(storageKey) || document.documentElement.lang || getPreferredLanguage()),
    setLanguage: applyLanguage
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initLanguageSwitcher);
  } else {
    initLanguageSwitcher();
  }
})();
