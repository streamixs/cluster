configs:
  cm:
    oidc.config: |
      name: Pocket ID
      issuer: https://auth.streamixs.com
      clientID: ${client_id}
      clientSecret: $argocd-oidc:client-secret
      requestedScopes:
        - openid
        - profile
        - email
      requestedIDTokenClaims:
        email:
          essential: true
  rbac:
    # Le claim email sert de sujet RBAC (Pocket-ID ne fournit pas de groupes).
    scopes: "[email]"
    policy.csv: |
      g, ${admin_email}, role:admin
