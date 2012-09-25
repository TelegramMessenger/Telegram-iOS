## Introduction

HockeySDK provides integrated setup support for the Atlassian JMC client. This allows you to use the Jira setup data from the corresponding app entry on HockeyApp instead of setting up JMC in code.

The benefit is that if anything changes on your Jira setup, you only have to change it in HockeyApp and all your app installations will use the new setup too.

**Important:** The binary distribution does not have this functionality integrated!

## HowTo

Use the [Installation & Setup Advanced](Guide-Installation-Setup-Advanced) which by default integrates JMC


## HowTo - Cocoapods

Add the compiler preprocessor definition `JIRA_MOBILE_CONNECT_SUPPORT_ENABLED=1`
