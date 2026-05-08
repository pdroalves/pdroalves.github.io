import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';
import { siteConfig } from '../config';

export async function GET(context) {
  const posts = (await getCollection('articles'))
    .filter(post => post.data.date)
    .sort((a, b) => new Date(b.data.date).getTime() - new Date(a.data.date).getTime());

  return rss({
    title: siteConfig.title,
    description: siteConfig.description,
    site: context.site,
    items: posts.map((post) => ({
      title: post.data.title,
      pubDate: new Date(post.data.date),
      description: post.data.description,
      link: `/blog/${post.id}/`,
    })),
  });
}
