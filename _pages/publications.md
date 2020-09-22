---
layout: archive
title: "Publications"
permalink: /publications/
author_profile: true
---

{% if author.googlescholar %}
  You can also find my articles on <u><a href="{{author.googlescholar}}">my Google Scholar profile</a>.</u>
{% endif %}

{% include base_path %}

Refereed publications in local events
{% for post in site.publications reversed %}
  {% include archive-single.html %}
{% endfor %}

Journal articles
{% for post in site.journalarticles reversed %}
  {% include archive-single.html %}
{% endfor %}

Contests
{% for post in site.contestspublications reversed %}
  {% include archive-single.html %}
{% endfor %}

Thesis/Dissertation
{% for post in site.dissertations reversed %}
  {% include archive-single.html %}
{% endfor %}
