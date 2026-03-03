#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { NarTrackerStack } from '../lib/nar-tracker-stack';

const app = new cdk.App();
new NarTrackerStack(app, 'NarTrackerStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION,
  },
});
