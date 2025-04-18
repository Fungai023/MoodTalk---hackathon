package ch.planner.authenticators;

import static org.keycloak.protocol.oidc.OIDCLoginProtocol.LOGIN_HINT_PARAM;

import java.util.Map;
import java.util.stream.Collectors;
import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.models.FederatedIdentityModel;
import org.keycloak.models.IdentityProviderModel;
import org.keycloak.models.UserModel;
import org.keycloak.protocol.oidc.OIDCLoginProtocol;
import org.keycloak.services.managers.ClientSessionCode;
import org.keycloak.sessions.AuthenticationSessionModel;

/**
 * This is a fork from https://github.com/sventorben/keycloak-home-idp-discovery
 */
final class LoginHint {

  private final AuthenticationFlowContext context;
  private final Users users;

  LoginHint(AuthenticationFlowContext context, Users users) {
    this.context = context;
    this.users = users;
  }

  void setInAuthSession(IdentityProviderModel homeIdp, String username) {
    if (homeIdp == null) {
      return;
    }
    String loginHint;
    UserModel user = users.lookupBy(username);
    if (user != null) {
      Map<String, String> idpToUsername = context
        .getSession()
        .users()
        .getFederatedIdentitiesStream(context.getRealm(), user)
        .collect(Collectors.toMap(FederatedIdentityModel::getIdentityProvider, FederatedIdentityModel::getUserName));
      loginHint = idpToUsername.getOrDefault(homeIdp.getAlias(), username);
      setInAuthSession(loginHint);
    }
  }

  void setInAuthSession(String loginHint) {
    context.getAuthenticationSession().setClientNote(OIDCLoginProtocol.LOGIN_HINT_PARAM, loginHint);
  }

  String getFromSession() {
    return context.getAuthenticationSession().getClientNote(LOGIN_HINT_PARAM);
  }

  void copyTo(ClientSessionCode<AuthenticationSessionModel> clientSessionCode) {
    String loginHint = getFromSession();
    if (clientSessionCode.getClientSession() != null && loginHint != null) {
      clientSessionCode.getClientSession().setClientNote(OIDCLoginProtocol.LOGIN_HINT_PARAM, loginHint);
    }
  }
}
