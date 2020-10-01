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

<h2>Pre-prints</h2>
{% for post in site.preprints reversed %}
  {% include archive-single.html %}
{% endfor %}

<hr>

<h2>Journal articles</h2>
{% for post in site.journals reversed %}
  {% include archive-single.html %}
{% endfor %}

<hr>

<h2>Refereed publications in local events</h2>
{% for post in site.publications reversed %}
  {% include archive-single.html %}
{% endfor %}

<hr>

<h2>Contests</h2>
{% for post in site.contests reversed %}
  {% include archive-single.html %}
{% endfor %}

<hr>

<h2>Thesis/Dissertation</h2>
{% for post in site.dissertations reversed %}
  {% include archive-single.html %}
{% endfor %}
