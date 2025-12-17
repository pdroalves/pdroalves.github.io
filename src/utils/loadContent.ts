// Utility functions for loading content files
// Note: In Astro, we use import.meta.glob for static file loading at build time

export async function loadYAMLContent<T>(filePath: string): Promise<T | null> {
  try {
    // Use Astro's import.meta.glob to load YAML files
    const modules = import.meta.glob('/src/content/**/*.yaml', { 
      eager: true,
      import: 'default'
    });
    
    const fullPath = `/src/content/${filePath}`;
    const module = modules[fullPath] as T | undefined;
    
    if (module) {
      return module;
    }
  } catch (error) {
    console.error(`Error loading YAML file ${filePath}:`, error);
  }
  return null;
}

export async function loadMarkdownContent(filePath: string): Promise<string | null> {
  try {
    const modules = import.meta.glob('/src/content/**/*.md', { 
      eager: true,
      query: '?raw'
    });
    
    const fullPath = `/src/content/${filePath}`;
    const module = modules[fullPath] as string | undefined;
    
    if (module) {
      return module;
    }
  } catch (error) {
    console.error(`Error loading Markdown file ${filePath}:`, error);
  }
  return null;
}
