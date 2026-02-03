// Web: redirect current tab to PDF URL.
import 'dart:html' as html;

void redirectToPdf(String url) {
  html.window.location.href = url;
}
