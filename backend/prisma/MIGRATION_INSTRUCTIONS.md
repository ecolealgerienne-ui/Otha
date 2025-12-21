# Instructions pour créer la migration Prisma

Après avoir ajouté les modèles Product, Order et OrderItem au schema.prisma, vous devez créer et appliquer la migration :

```bash
# 1. Générer la migration
npx prisma migrate dev --name add_petshop_models

# 2. Générer le client Prisma
npx prisma generate

# 3. (Optionnel) Si vous êtes en production
npx prisma migrate deploy
```

## Modèles ajoutés

- **Product** : Produits de l'animalerie
- **Order** : Commandes des clients
- **OrderItem** : Articles dans une commande
- **OrderStatus** : Enum pour les statuts de commande (PENDING, CONFIRMED, SHIPPED, DELIVERED, CANCELLED)

## Relations ajoutées

- `User.orders` : Les commandes d'un utilisateur
- `ProviderProfile.products` : Les produits d'un provider
- `ProviderProfile.orders` : Les commandes d'un provider
- `Product.orderItems` : Les items de commande qui utilisent ce produit
- `Order.items` : Les articles d'une commande



