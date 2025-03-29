#
# Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com),
# Pellegrino Prevete (pellegrinoprevete@gmail.com)  2014-2025
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#
from ctypes.util import find_library
from ctypes import *
import json
import os
import sys

# load shared library
tdjson_path = find_library('tdjson')
if tdjson_path is None:
    if os.name == 'nt':
        tdjson_path = os.path.join(os.path.dirname(__file__), 'tdjson.dll')
    else:
        sys.exit("Can't find 'tdjson' library")
tdjson = CDLL(tdjson_path)

# load TDLib functions from shared library
_td_create_client_id = tdjson.td_create_client_id
_td_create_client_id.restype = c_int
_td_create_client_id.argtypes = []

_td_receive = tdjson.td_receive
_td_receive.restype = c_char_p
_td_receive.argtypes = [c_double]

_td_send = tdjson.td_send
_td_send.restype = None
_td_send.argtypes = [c_int, c_char_p]

_td_execute = tdjson.td_execute
_td_execute.restype = c_char_p
_td_execute.argtypes = [c_char_p]

log_message_callback_type = CFUNCTYPE(None, c_int, c_char_p)

_td_set_log_message_callback = tdjson.td_set_log_message_callback
_td_set_log_message_callback.restype = None
_td_set_log_message_callback.argtypes = [c_int, log_message_callback_type]

# initialize TDLib log with desired parameters
@log_message_callback_type
def on_log_message_callback(verbosity_level, message):
    if verbosity_level == 0:
        sys.exit('TDLib fatal error: %r' % message)

def td_execute(query):
    query = json.dumps(query).encode('utf-8')
    result = _td_execute(query)
    if result:
        result = json.loads(result.decode('utf-8'))
    return result

_td_set_log_message_callback(2, on_log_message_callback)

# setting TDLib log verbosity level to 1 (errors)
print(str(td_execute({'@type': 'setLogVerbosityLevel', 'new_verbosity_level': 1, '@extra': 1.01234})).encode('utf-8'))


# create client
client_id = _td_create_client_id()

# simple wrappers for client usage
def td_send(query):
    query = json.dumps(query).encode('utf-8')
    _td_send(client_id, query)

def td_receive():
    result = _td_receive(1.0)
    if result:
        result = json.loads(result.decode('utf-8'))
    return result

# another test for TDLib execute method
print(str(td_execute({'@type': 'getTextEntities', 'text': '@telegram /test_command https://telegram.org telegram.me', '@extra': ['5', 7.0, 'a']})).encode('utf-8'))

# start the client by sending a request to it
td_send({'@type': 'getOption', 'name': 'version', '@extra': 1.01234})

# main events cycle
while True:
    event = td_receive()
    if event:
        # process authorization states
        if event['@type'] == 'updateAuthorizationState':
            auth_state = event['authorization_state']

            # if client is closed, we need to destroy it and create new client
            if auth_state['@type'] == 'authorizationStateClosed':
                break

            # set TDLib parameters
            # you MUST obtain your own api_id and api_hash at https://my.telegram.org
            # and use them in the setTdlibParameters call
            if auth_state['@type'] == 'authorizationStateWaitTdlibParameters':
                td_send({'@type': 'setTdlibParameters',
                         'database_directory': 'tdlib',
                         'use_message_database': True,
                         'use_secret_chats': True,
                         'api_id': 94575,
                         'api_hash': 'a3406de8d171bb422bb6ddf3bbd800e2',
                         'system_language_code': 'en',
                         'device_model': 'Desktop',
                         'application_version': '1.0'})

            # enter phone number to log in
            if auth_state['@type'] == 'authorizationStateWaitPhoneNumber':
                phone_number = input('Please enter your phone number: ')
                td_send({'@type': 'setAuthenticationPhoneNumber', 'phone_number': phone_number})

            # enter email address to log in
            if auth_state['@type'] == 'authorizationStateWaitEmailAddress':
                email_address = input('Please enter your email address: ')
                td_send({'@type': 'setAuthenticationEmailAddress', 'email_address': email_address})

            # wait for email authorization code
            if auth_state['@type'] == 'authorizationStateWaitEmailCode':
                code = input('Please enter the email authentication code you received: ')
                td_send({'@type': 'checkAuthenticationEmailCode',
                         'code': {'@type': 'emailAddressAuthenticationCode', 'code' : code}})

            # wait for authorization code
            if auth_state['@type'] == 'authorizationStateWaitCode':
                code = input('Please enter the authentication code you received: ')
                td_send({'@type': 'checkAuthenticationCode', 'code': code})

            # wait for first and last name for new users
            if auth_state['@type'] == 'authorizationStateWaitRegistration':
                first_name = input('Please enter your first name: ')
                last_name = input('Please enter your last name: ')
                td_send({'@type': 'registerUser', 'first_name': first_name, 'last_name': last_name})

            # wait for password if present
            if auth_state['@type'] == 'authorizationStateWaitPassword':
                password = input('Please enter your password: ')
                td_send({'@type': 'checkAuthenticationPassword', 'password': password})

        # handle an incoming update or an answer to a previously sent request
        print(str(event).encode('utf-8'))
        sys.stdout.flush()
