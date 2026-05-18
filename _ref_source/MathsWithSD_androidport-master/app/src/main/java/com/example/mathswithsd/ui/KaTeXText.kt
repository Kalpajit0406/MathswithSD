package com.example.mathswithsd.ui

import android.annotation.SuppressLint
import android.webkit.WebView
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun KaTeXText(
    text: String,
    modifier: Modifier = Modifier
) {
    val baseHtml = remember {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.css">
            <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.js"></script>
            <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/contrib/auto-render.min.js"></script>
            <style>
                body {
                    font-family: sans-serif;
                    font-size: 16px;
                    color: #333333;
                    margin: 0;
                    padding: 4px;
                    word-wrap: break-word;
                }
                #content { visibility: hidden; }
            </style>
            <script>
                function updateContent(newText) {
                    var container = document.getElementById('content');
                    container.innerHTML = newText;
                    if (window.renderMathInElement) {
                        renderMathInElement(container, {
                              delimiters: [
                                  {left: '${'$'}${'$'}', right: '${'$'}${'$'}', display: true},
                                  {left: '${'$'}', right: '${'$'}', display: false},
                                  {left: '\\(', right: '\\)', display: false},
                                  {left: '\\[', right: '\\]', display: true}
                              ]
                          });
                        container.style.visibility = 'visible';
                    } else {
                        // KaTeX not loaded yet, wait and retry
                        setTimeout(function() { updateContent(newText); }, 50);
                    }
                }
            </script>
        </head>
        <body>
            <div id="content"></div>
        </body>
        </html>
        """.trimIndent()
    }

    // Escape text for javascript string injection
    val escapedText = remember(text) {
        text.replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("'", "\\'")
            .replace("\n", "\\n")
            .replace("\r", "")
    }

    AndroidView(
        modifier = modifier.fillMaxWidth(),
        factory = { context ->
            WebView(context).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                setBackgroundColor(0x00000000)
                loadDataWithBaseURL(null, baseHtml, "text/html", "UTF-8", null)
                
                webViewClient = object : android.webkit.WebViewClient() {
                    override fun onPageFinished(view: WebView, url: String?) {
                        view.evaluateJavascript("updateContent('${escapedText}');", null)
                    }
                }
            }
        },
        update = { webView ->
            webView.evaluateJavascript("if(document.getElementById('content')) updateContent('${escapedText}');", null)
        }
    )
}
