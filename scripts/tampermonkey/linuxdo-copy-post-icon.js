// ==UserScript==
// @name         Linux.do 帖子复制按钮（精准顺序）
// @namespace    http://tampermonkey.net/
// @version      4.0
// @description  复制按钮插入在点赞左侧，顺序：复制+ 复制 点赞数 点赞 复制链接
// @author       You
// @match        https://linux.do/t/*
// @grant        none
// @license      MIT
// ==/UserScript==

(function () {
    'use strict';

    // ====== 专业 SVG 图标 ======
    const ICON_LINK = `
        <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"></path>
            <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"></path>
        </svg>
    `;

    const ICON_TEXT = `
        <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
            <polyline points="14 2 14 8 20 8"></polyline>
            <line x1="16" y1="13" x2="8" y2="13"></line>
            <line x1="16" y1="17" x2="8" y2="17"></line>
            <line x1="10" y1="9" x2="8" y2="9"></line>
        </svg>
    `;

    const ICON_CHECK = `
        <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M20 6L9 17l-5-5"/>
        </svg>
    `;

    // ====== 样式 ======
    const STYLE = `
        <style>
            .ld-copy-btn {
                margin-right: 8px;
                padding: 4px;
                background: transparent;
                border: none;
                cursor: pointer;
                color: #8b949e;
                border-radius: 4px;
                transition: all 0.2s;
                display: inline-flex;
                align-items: center;
                justify-content: center;
            }
            .ld-copy-btn:hover {
                background: #f6f8fa;
                color: #24292f;
            }
            .ld-copy-btn.copied {
                color: #f56c6c !important;
            }
            .ld-copy-btn svg {
                width: 14px;
                height: 14px;
            }
        </style>
    `;

    document.head.insertAdjacentHTML('beforeend', STYLE);

    // ====== 工具函数 ======
    function getCleanUrl() {
        const url = new URL(window.location.href);
        url.searchParams.delete('u');
        return url.toString();
    }

    function getPostText(cooked) {
        if (!cooked) return '';
        const clone = cooked.cloneNode(true);
        clone.querySelectorAll('aside.quote, button, .md-code-copy, .ld-copy-btn').forEach(el => el.remove());
        return clone.innerText.trim();
    }

    // ====== 创建按钮 ======
    function createButton(iconSvg, title, onClick) {
        const btn = document.createElement('button');
        btn.className = 'ld-copy-btn';
        btn.innerHTML = iconSvg;
        btn.title = title;
        btn.onclick = async (e) => {
            e.preventDefault();
            e.stopPropagation();
            try {
                await onClick();
                const originalSvg = btn.innerHTML;
                btn.innerHTML = ICON_CHECK;
                btn.classList.add('copied');
                setTimeout(() => {
                    btn.innerHTML = originalSvg;
                    btn.classList.remove('copied');
                }, 1500);
            } catch (err) {
                console.error('复制失败:', err);
            }
        };
        return btn;
    }

    // ====== 核心：插入到点赞按钮左侧 ======
    function processPost(article) {
        if (article.dataset.ldCopyAdded) return;
        article.dataset.ldCopyAdded = 'true';

        const controls = article.querySelector('.post-controls');
        if (!controls) return;

        const cooked = article.querySelector('.cooked');
        if (!cooked) return;

        const contentText = getPostText(cooked);
        const cleanUrl = getCleanUrl();

        // 清理旧按钮
        controls.querySelectorAll('.ld-copy-btn').forEach(b => b.remove());

        // 创建按钮
        const btnLink = createButton(ICON_LINK, '复制内容 + 链接 + #Linuxdo', async () => {
            await navigator.clipboard.writeText(`${contentText}\n\n${cleanUrl}\n#Linuxdo`);
        });

        const btnText = createButton(ICON_TEXT, '仅复制帖子内容', async () => {
            await navigator.clipboard.writeText(contentText);
        });

        // 找到点赞按钮（第一个 .widget-button.like 或 .like-count）
        const likeButton = controls.querySelector('.widget-button.like, .like-count');
        if (likeButton) {
            // 插入到点赞按钮之前
            likeButton.parentNode.insertBefore(btnText, likeButton);
            likeButton.parentNode.insertBefore(btnLink, likeButton);
        } else {
            // 兜底：插入到最前
            controls.prepend(btnLink, btnText);
        }
    }

    // ====== 批量处理 ======
    function processAllPosts() {
        document.querySelectorAll('article.topic-post, article[data-post-id]:not([data-post-id=""])')
            .forEach(post => {
                try { processPost(post); } catch (e) { console.warn(e); }
            });
    }

    // ====== 初始化 & 动态监听 ======
    const init = () => {
        setTimeout(processAllPosts, 1000);

        const observer = new MutationObserver(mutations => {
            let shouldRun = false;
            for (const m of mutations) {
                if (m.addedNodes.length) {
                    for (const node of m.addedNodes) {
                        if (node.nodeType === 1) {
                            if (node.matches?.('article.topic-post, article[data-post-id]') ||
                                node.querySelector?.('article.topic-post, article[data-post-id]')) {
                                shouldRun = true;
                                break;
                            }
                        }
                    }
                }
            }
            if (shouldRun) setTimeout(processAllPosts, 400);
        });

        observer.observe(document.body, { childList: true, subtree: true });
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    console.log('Linux.do 复制按钮 v4.0（精准顺序）已加载');
})();
