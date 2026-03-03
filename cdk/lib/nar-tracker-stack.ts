import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigwv2 from 'aws-cdk-lib/aws-apigatewayv2';
import * as apigwv2integrations from 'aws-cdk-lib/aws-apigatewayv2-integrations';
import * as apigwv2authorizers from 'aws-cdk-lib/aws-apigatewayv2-authorizers';
import * as path from 'path';

export class NarTrackerStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // --- Cognito ---
    const userPool = new cognito.UserPool(this, 'UserPool', {
      userPoolName: 'nar-tracker-users',
      selfSignUpEnabled: true,
      signInAliases: { email: true },
      autoVerify: { email: true },
      passwordPolicy: {
        minLength: 8,
        requireDigits: true,
        requireLowercase: true,
        requireUppercase: false,
        requireSymbols: false,
      },
      accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
      removalPolicy: cdk.RemovalPolicy.RETAIN, // don't delete on cdk destroy
    });

    // Hosted UI domain — must be globally unique; change the prefix if deploy fails
    const userPoolDomain = userPool.addDomain('Domain', {
      cognitoDomain: { domainPrefix: 'nar-tracker' },
    });

    const userPoolClient = userPool.addClient('iOSClient', {
      userPoolClientName: 'nar-tracker-ios',
      generateSecret: false, // public client (required for PKCE on mobile)
      authFlows: {
        userPassword: false,
        userSrp: false,
      },
      oAuth: {
        flows: { authorizationCodeGrant: true },
        scopes: [
          cognito.OAuthScope.OPENID,
          cognito.OAuthScope.EMAIL,
          cognito.OAuthScope.PROFILE,
        ],
        callbackUrls: ['nartracker://callback'],
        logoutUrls: ['nartracker://logout'],
      },
      accessTokenValidity: cdk.Duration.hours(1),
      idTokenValidity: cdk.Duration.hours(1),
      refreshTokenValidity: cdk.Duration.days(30),
      supportedIdentityProviders: [cognito.UserPoolClientIdentityProvider.COGNITO],
    });

    // --- DynamoDB ---
    const table = new dynamodb.Table(this, 'SymptomsTable', {
      tableName: 'nar-symptoms',
      partitionKey: { name: 'user_id', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'submission_time', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST, // free tier, scales to zero
      removalPolicy: cdk.RemovalPolicy.RETAIN, // never delete your data accidentally
    });

    // --- Lambda ---
    const fn = new lambda.Function(this, 'LogSymptom', {
      functionName: 'nar-tracker-log-symptom',
      runtime: lambda.Runtime.PYTHON_3_12,
      handler: 'lambda_function.lambda_handler',
      code: lambda.Code.fromAsset(path.join(__dirname, '../lambda')),
      environment: { TABLE_NAME: table.tableName },
      timeout: cdk.Duration.seconds(10),
    });

    table.grantWriteData(fn);

    // --- API Gateway (HTTP API) ---
    const api = new apigwv2.HttpApi(this, 'Api', {
      apiName: 'nar-tracker-api',
    });

    const authorizer = new apigwv2authorizers.HttpJwtAuthorizer(
      'CognitoAuthorizer',
      `https://cognito-idp.${this.region}.amazonaws.com/${userPool.userPoolId}`,
      {
        jwtAudience: [userPoolClient.userPoolClientId],
      }
    );

    api.addRoutes({
      path: '/log',
      methods: [apigwv2.HttpMethod.POST],
      integration: new apigwv2integrations.HttpLambdaIntegration('LogIntegration', fn),
      authorizer,
    });

    // --- Outputs (paste these into ios/NARTracker/Constants.swift) ---
    new cdk.CfnOutput(this, 'ApiEndpoint', {
      value: `${api.apiEndpoint}/log`,
      description: 'API endpoint — paste into Constants.apiEndpoint',
    });
    new cdk.CfnOutput(this, 'UserPoolId', {
      value: userPool.userPoolId,
      description: 'Cognito User Pool ID — paste into Constants.cognitoUserPoolId',
    });
    new cdk.CfnOutput(this, 'UserPoolClientId', {
      value: userPoolClient.userPoolClientId,
      description: 'Cognito Client ID — paste into Constants.cognitoClientId',
    });
    new cdk.CfnOutput(this, 'CognitoDomain', {
      value: userPoolDomain.baseUrl(),
      description: 'Cognito Hosted UI base URL — paste into Constants.cognitoDomain',
    });
    new cdk.CfnOutput(this, 'AwsRegion', {
      value: this.region,
      description: 'AWS region — paste into Constants.cognitoRegion',
    });
  }
}
