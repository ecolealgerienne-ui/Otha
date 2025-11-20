// Générateur de noms anonymes sympas pour les conversations d'adoption
// Ex: "Ami des Animaux", "Cœur Tendre", "Ange Gardien"

const ADJECTIVES = [
  'Généreux',
  'Tendre',
  'Doux',
  'Bienveillant',
  'Attentionné',
  'Dévoué',
  'Fidèle',
  'Chaleureux',
  'Affectueux',
  'Protecteur',
  'Sage',
  'Patient',
  'Gentil',
  'Sincère',
  'Joyeux',
  'Lumineux',
  'Rayonnant',
  'Adorable',
  'Merveilleux',
  'Précieux',
];

const NOUNS = [
  'Ami des Animaux',
  'Cœur',
  'Ange Gardien',
  'Protecteur',
  'Sauveur',
  'Bienfaiteur',
  'Compagnon',
  'Refuge',
  'Espoir',
  'Lumière',
  'Gardien',
  'Guide',
  'Confident',
  'Allié',
  'Défenseur',
  'Adoptant',
  'Héros',
  'Champion',
  'Sauveteur',
  'Parrain',
];

/**
 * Génère un nom anonyme aléatoire de type "Adjectif + Nom"
 * Ex: "Tendre Cœur", "Généreux Protecteur", "Doux Ami des Animaux"
 *
 * @param seed - Optionnel: graine pour générer toujours le même nom (ex: userId)
 * @returns Un nom anonyme sympa
 */
export function generateAnonymousName(seed?: string): string {
  if (seed) {
    // Génération déterministe basée sur le seed
    const hash = simpleHash(seed);
    const adjIndex = hash % ADJECTIVES.length;
    const nounIndex = Math.floor(hash / ADJECTIVES.length) % NOUNS.length;
    return `${ADJECTIVES[adjIndex]} ${NOUNS[nounIndex]}`;
  }

  // Génération aléatoire
  const adj = ADJECTIVES[Math.floor(Math.random() * ADJECTIVES.length)];
  const noun = NOUNS[Math.floor(Math.random() * NOUNS.length)];
  return `${adj} ${noun}`;
}

/**
 * Hash simple pour convertir une string en nombre
 * Utilisé pour générer un nom déterministe à partir d'un seed
 */
function simpleHash(str: string): number {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash = hash & hash; // Convert to 32bit integer
  }
  return Math.abs(hash);
}
