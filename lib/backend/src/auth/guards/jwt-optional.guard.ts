import { Injectable, ExecutionContext } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/**
 * Guard JWT optionnel : authentifie l'utilisateur si un token est présent,
 * mais ne bloque pas si absent ou invalide.
 * Utile pour les endpoints publics qui veulent personnaliser la réponse
 * pour les utilisateurs connectés (ex: exclure ses propres posts du feed).
 */
@Injectable()
export class JwtOptionalGuard extends AuthGuard('jwt') {
  canActivate(context: ExecutionContext) {
    // Appelle la logique de AuthGuard('jwt')
    return super.canActivate(context);
  }

  handleRequest(err: any, user: any) {
    // Ne pas throw si pas de token ou token invalide
    // Simplement retourner null pour req.user
    if (err || !user) {
      return null;
    }
    return user;
  }
}
