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
        - groups
      requestedIDTokenClaims:
        email:
          essential: true
        groups:
          essential: true
      # Pocket-ID expose groups dans l'ID token et /api/oidc/userinfo.
      # enableUserInfoGroups sert de repli si le claim n'est pas dans l'ID token.
      enableUserInfoGroups: true
      userInfoURL: https://auth.streamixs.com
      userInfoPath: /api/oidc/userinfo
      userInfoCacheExpiration: 5m
  rbac:
    # Le claim groups sert de sujet RBAC (noms des groupes Pocket-ID).
    scopes: "[groups]"
    policy.csv: |
      g, ${admin_group}, role:admin
