import ldap
from django_auth_ldap.config import LDAPGroupQuery, LDAPSearch, GroupOfNamesType
from django_auth_ldap.backend import LDAPSettings
from netbox.authentication import NBLDAPBackend

"""
1. Save as /opt/netbox/local/authentication.py
2. Add the following config in /opt/netbox/netbox/netbox/configuration.py:
REMOTE_AUTH_BACKEND = ('local.authentication.ActiveDirectory1', 'local.authentication.ActiveDirectory2')
NetBox will attempt ActiveDirectory1, then ActiveDirectory2, when authenticating users.
"""

# Define NetBox LDAP groups
GROUP_READONLY = LDAPGroupQuery("CN=netbox_readonly,DC=example,DC=net")
GROUP_OPERATOR = LDAPGroupQuery("CN=netbox_oper,DC=example,DC=net")
GROUP_ADMIN = LDAPGroupQuery("CN=netbox_admin,DC=example,DC=net")

# LDAP settings
ldap.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)
LDAP_SETTINGS = LDAPSettings()
LDAP_SETTINGS.GLOBAL_OPTIONS = {ldap.OPT_REFERRALS: 0}
LDAP_SETTINGS.BIND_DN = "CN=nb_service_account,OU=ServiceAccounts,DC=example,DC=net"
LDAP_SETTINGS.BIND_PASSWORD = "s3cr3t"
# Per NetBox documentation, this should be None on Server 2012+
LDAP_SETTINGS.USER_DN_TEMPLATE = None
LDAP_SETTINGS.USER_ATTR_MAP = {
    "first_name": "givenName",
    "last_name": "sn",
    "email": "mail",
}
LDAP_SETTINGS.FIND_GROUP_PERMS = False
LDAP_SETTINGS.GROUP_SEARCH = LDAPSearch("OU=SecGroups,DC=example,DC=net", ldap.SCOPE_SUBTREE, "(objectClass=group)")
LDAP_SETTINGS.GROUP_TYPE = GroupOfNamesType()
LDAP_SETTINGS.REQUIRE_GROUP = GROUP_READONLY | GROUP_OPERATOR | GROUP_ADMIN
LDAP_SETTINGS.USER_FLAGS_BY_GROUP = {
    "is_active": (GROUP_READONLY | GROUP_OPERATOR | GROUP_ADMIN),
    "is_staff": GROUP_ADMIN,
    "is_superuser": GROUP_ADMIN,
}
LDAP_SETTINGS.MIRROR_GROUPS = [
    'ug_netbox_readonly',
    'ug_netbox_oper',
    'ug_netbox_admin',
]
LDAP_SETTINGS.CACHE_GROUPS = True
LDAP_SETTINGS.GROUP_CACHE_TIMEOUT = 3600

class ActiveDirectory1:
    def __new__(cls):
        LDAP_SETTINGS.SERVER_URI = 'ldaps://ad1.example.net:3269'
        LDAP_SETTINGS.USER_SEARCH = LDAPSearch("DC=ad1,DC=example,DC=net", ldap.SCOPE_SUBTREE, "(sAMAccountName=%(user)s)")
        backend = NBLDAPBackend()
        backend.settings = LDAP_SETTINGS
        return backend

class ActiveDirectory2:
    def __new__(cls):
        LDAP_SETTINGS.SERVER_URI = 'ldaps://ad2.example.net:3269'
        LDAP_SETTINGS.USER_SEARCH = LDAPSearch("DC=ad2,DC=example,DC=net", ldap.SCOPE_SUBTREE, "(sAMAccountName=%(user)s)")
        backend = NBLDAPBackend()
        backend.settings = LDAP_SETTINGS
        return backend