// ==UserScript==
// @name X copy post icon
// @namespace http://tampermonkey.net/
// @version 1.6
// @description Add two copy icons to each post's top right: default gray, hover blue. Supports copying full content of long posts after expanding "view more".
// @author Grok (for @littleauun)
// @match https://x.com/*
// @grant none
// @license MIT
// ==/UserScript==
(function () {
    'use strict';
    // SVG Icons
    const ICON_FULL = `
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="9" y="9" width="13" height="13" rx="2"></rect>
            <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
            <path d="M12 17h10"></path>
            <path d="M17 14v6"></path>
        </svg>`;
    const ICON_TEXT = `
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="9" y="9" width="13" height="13" rx="2"></rect>
            <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
        </svg>`;
    // Toast
    const showToast = (msg) => {
        const toast = document.createElement('div');
        toast.textContent = msg;
        toast.style.cssText = `
            position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%);
            background: rgba(29,161,242,0.95); color: white; padding: 10px 20px;
            border-radius: 8px; font-size: 14px; font-weight: 500; z-index: 10001;
            opacity: 0; transition: opacity 0.3s ease; pointer-events: none;
            backdrop-filter: blur(4px); box-shadow: 0 4px 12px rgba(0,0,0,0.2);
            font-family: system-ui, -apple-system, sans-serif;
        `;
        document.body.appendChild(toast);
        setTimeout(() => toast.style.opacity = '1', 10);
        setTimeout(() => {
            toast.style.opacity = '0';
            setTimeout(() => toast.remove(), 300);
        }, 1800);
    };
    // Copy
    const copy = async (text, msg) => {
        try {
            await navigator.clipboard.writeText(text);
            showToast(msg);
        } catch (e) {
            showToast('Copy failed');
            console.error(e);
        }
    };
    // Add icons
    const addCopyIcons = (article) => {
        if (article.querySelector('.x-copy-icons-jp')) return;
        const actionBar = article.querySelector('[data-testid="reply"], [data-testid="retweet"], [data-testid="like"]')?.closest('div[role="group"]');
        if (!actionBar) return;
        const linkEl = article.querySelector('a[href*="/status/"]');
        if (!linkEl) return;
        // Initial check for text existence (partial is fine)
        const textSpans = article.querySelectorAll('[data-testid="tweetText"] span');
        const initialText = Array.from(textSpans).map(s => s.textContent).join('').trim();
        if (!initialText) return;
        const container = document.createElement('div');
        container.className = 'x-copy-icons-jp';
        container.style.cssText = 'display: flex; gap: 12px; align-items: center; margin-left: 12px;';
        // Button: Copy Full
        const btnFull = createIconButton(ICON_FULL, 'Copy full (link + #X)', 'Copy full');
        btnFull.onclick = (e) => {
            e.preventDefault(); e.stopPropagation();
            const article = e.target.closest('article');
            if (!article) return;
            const linkEl = article.querySelector('a[href*="/status/"]');
            if (!linkEl) return;
            const postLink = 'https://x.com' + linkEl.getAttribute('href').split('?')[0];
            const textSpans = article.querySelectorAll('[data-testid="tweetText"] span');
            const postText = Array.from(textSpans).map(s => s.textContent).join('').trim();
            if (!postText) return;
            copy(`${postText}\n${postLink}\n#X`, 'Full copied!');
        };
        // Button: Copy Text
        const btnText = createIconButton(ICON_TEXT, 'Copy text only', 'Copy text');
        btnText.onclick = (e) => {
            e.preventDefault(); e.stopPropagation();
            const article = e.target.closest('article');
            if (!article) return;
            const textSpans = article.querySelectorAll('[data-testid="tweetText"] span');
            const postText = Array.from(textSpans).map(s => s.textContent).join('').trim();
            if (!postText) return;
            copy(postText, 'Text copied!');
        };
        container.appendChild(btnFull);
        container.appendChild(btnText);
        actionBar.appendChild(container);
    };
    // Helper: create icon button with gray → blue hover
    const createIconButton = (svg, title, aria) => {
        const btn = document.createElement('button');
        btn.innerHTML = svg;
        btn.title = title;
        btn.setAttribute('aria-label', aria);
        btn.style.cssText = `
            all: unset; cursor: pointer; display: flex; align-items: center;
            padding: 8px; border-radius: 9999px; transition: all 0.2s ease;
            color: #546571; /* Default gray */
        `;
        btn.addEventListener('mouseenter', () => {
            btn.style.color = '#1d9bf0'; /* X blue */
            btn.style.background = 'rgba(29, 161, 242, 0.1)';
        });
        btn.addEventListener('mouseleave', () => {
            btn.style.color = '#546571';
            btn.style.background = '';
        });
        return btn;
    };
    // Observer
    const observer = new MutationObserver((mutations) => {
        mutations.forEach(m => {
            m.addedNodes.forEach(node => {
                if (node.nodeType !== 1) return;
                if (node.tagName === 'ARTICLE') addCopyIcons(node);
                node.querySelectorAll?.('article').forEach(addCopyIcons);
            });
        });
    });
    observer.observe(document.body, { childList: true, subtree: true });
    document.querySelectorAll('article').forEach(addCopyIcons);
    // SPA navigation
    let lastUrl = location.href;
    new MutationObserver(() => {
        const url = location.href;
        if (url !== lastUrl) {
            lastUrl = url;
            setTimeout(() => document.querySelectorAll('article').forEach(addCopyIcons), 800);
        }
    }).observe(document, { subtree: true, childList: true });
})();