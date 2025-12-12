import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const ReqUser = createParamDecorator(
  (data: string | undefined, ctx: ExecutionContext) => {
    const req = ctx.switchToHttp().getRequest();
    const user = req.user || {};

    // Normalise pour offrir `id` même si la stratégie ne renvoie que `sub`
    const normalized =
      user?.id != null
        ? user
        : {
            ...user,
            id: user?.sub ?? user?.userId ?? user?.uid,
          };

    return data ? normalized?.[data] : normalized;
  },
);
