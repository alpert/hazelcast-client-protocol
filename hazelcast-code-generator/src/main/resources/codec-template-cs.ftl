// Copyright (c) 2008-2017, Hazelcast, Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

using System;
using System.Collections.Generic;
using Hazelcast.Client.Protocol;
using Hazelcast.Client.Protocol.Util;
using Hazelcast.IO;
using Hazelcast.IO.Serialization;

// Client Protocol version, Since:${model.messageSince} - Update:${util.versionAsString(model.highestParameterVersion)}
namespace ${model.packageName}
{
    internal sealed class ${model.className}
    {

        public static readonly ${model.parentName}MessageType RequestType = ${model.parentName}MessageType.${model.parentName?cap_first}${model.name?cap_first};
        public const int ResponseType = ${model.response};
        public const bool Retryable = <#if model.retryable == 1>true<#else>false</#if>;

        //************************ REQUEST *************************//

        public class RequestParameters
        {
            public static readonly ${model.parentName}MessageType TYPE = RequestType;
    <#list model.requestParams as param>
            public ${util.getCSharpType(param.type)} ${param.name};
    </#list>

            public static int CalculateDataSize(<#list model.requestParams as param>${util.getCSharpType(param.type)} ${param.name}<#if param_has_next>, </#if></#list>)
            {
                var dataSize = ClientMessage.HeaderSize;
                <#list model.requestParams as p>
                    <@sizeText var_name=p.name type=p.type isNullable=p.nullable containsNullable=p.containsNullable/>
                </#list>
                return dataSize;
            }
        }

        public static ClientMessage EncodeRequest(<#list model.requestParams as param>${util.getCSharpType(param.type)} ${param.name}<#if param_has_next>, </#if></#list>)
        {
            var requiredDataSize = RequestParameters.CalculateDataSize(<#list model.requestParams as param>${param.name}<#if param_has_next>, </#if></#list>);
            var clientMessage = ClientMessage.CreateForEncode(requiredDataSize);
            clientMessage.SetMessageType((int)RequestType);
            clientMessage.SetRetryable(Retryable);
            <#list model.requestParams as p>
                <@setterText var_name=p.name type=p.type isNullable=p.nullable containsNullable=p.containsNullable/>
            </#list>
            clientMessage.UpdateFrameLength();
            return clientMessage;
        }

<#if model.responseParams?has_content>
        //************************ RESPONSE *************************//
        public class ResponseParameters
        {
            <#list model.responseParams as param>
            public ${util.getCSharpType(param.type)} ${param.name};
                <#assign messageVersion=model.messageSinceInt>
            <#if param.sinceVersionInt gt messageVersion>
            public bool ${param.name}Exist;
            </#if>
            </#list>
        }

        public static ResponseParameters DecodeResponse(IClientMessage clientMessage)
        {
            var parameters = new ResponseParameters();
<#list model.responseParams as p>
<#if p.versionChanged>
            if (clientMessage.IsComplete())
            {
                return parameters;
            }
</#if>
<@getterText var_name=p.name type=p.type isNullable=p.nullable containsNullable=p.containsNullable/>
<#if p.sinceVersionInt gt messageVersion>
            parameters.${p.name}Exist = true;
</#if>
</#list>
            return parameters;
        }
<#else>
        //************************ RESPONSE IS EMPTY *****************//
</#if>

    <#if model.events?has_content>
//************************ EVENTS *************************//
        public abstract class AbstractEventHandler
        {
            public static void Handle(IClientMessage clientMessage, <#list model.events as event>Handle${event.name} handle${event.name}<#if event_has_next>, </#if></#list>)
            {
                var messageType = clientMessage.GetMessageType();
            <#list model.events as event>
                if (messageType == EventMessageConst.Event${event.name?cap_first})
                {
                <#assign hasCodecRevision=false>
                <#list event.eventParams as p>
                    <#assign hasCodecRevision=hasCodecRevision || p.versionChanged>
                </#list>
                <#if hasCodecRevision>
                    var ${event.name}MessageFinished = false;
                </#if>
                <#assign messageVersion=model.messageSinceInt>
                <#list event.eventParams as p>
                    <#if p.versionChanged>
                    if (!${event.name}MessageFinished)
                    {
                        ${event.name}MessageFinished = clientMessage.IsComplete();
                    }
                    </#if>
                    <#if p.nullable || p.sinceVersionInt gt messageVersion>
                    ${util.getCSharpType(p.type)}<#if util.isNonNullable(p.type)>?</#if> ${p.name} = null;
                    </#if>
                    <#if p.sinceVersionInt gt messageVersion>
                    if (!${event.name}MessageFinished)
                    {
                    </#if>
                        <@readVariable var_name=p.name type=p.type isNullable=p.nullable isEvent=true local= !(p.nullable || p.sinceVersionInt gt messageVersion)/>
                    <#if p.sinceVersionInt gt messageVersion>
                    }
                    </#if>
                </#list>
                    handle${event.name}(<#list event.eventParams as param>${param.name}<#if param_has_next>, </#if></#list>);
                    return;
                }
            </#list>
                Hazelcast.Logging.Logger.GetLogger(typeof(AbstractEventHandler)).Warning("Unknown message type received on event handler :" + clientMessage.GetMessageType());
            }

        <#list model.events as event>
            public delegate void Handle${event.name}(<#list event.eventParams as p>${defineVariableFnc(p.name,p.type, p.sinceVersionInt gt messageVersion)}<#if p_has_next>, </#if></#list>);
        </#list>
       }
    </#if>
    }
}
<#--MACROS BELOW-->
<#--SIZE NULL CHECK MACRO -->
<#macro sizeText var_name type isNullable=false containsNullable=false>
<#if isNullable>
                dataSize += Bits.BooleanSizeInBytes;
                if (${var_name} != null)
                {
</#if>
                    <@sizeTextInternal var_name=var_name type=type containsNullable=containsNullable/>
<#if isNullable>
                }
</#if>
</#macro>
<#--SIZE MACRO -->
<#macro sizeTextInternal var_name type containsNullable=false>
<#local cat= util.getTypeCategory(type)>
<#switch cat>
    <#case "OTHER">
        <#if util.isPrimitive(type)>
                dataSize += Bits.${type?cap_first}SizeInBytes;
        <#else >
                dataSize += ParameterUtil.CalculateDataSize(${var_name});
        </#if>
        <#break >
    <#case "CUSTOM">
                dataSize += ${util.getTypeCodec(type)?split(".")?last}.CalculateDataSize(${var_name});
        <#break >
    <#case "COLLECTION">
                dataSize += Bits.IntSizeInBytes;
        <#local genericType= util.getGenericType(type)>
        <#local n= var_name>
        <#local itemTypeVar= var_name + "Item">
                foreach (var ${itemTypeVar} in ${var_name} )
                {
                    <@sizeText var_name="${n}Item" type=genericType isNullable=containsNullable/>
                }
        <#break >
    <#case "ARRAY">
                dataSize += Bits.IntSizeInBytes;
        <#local genericType= util.getArrayType(type)>
        <#local n= var_name>
        <#local itemTypeVar= var_name + "Item">
                foreach (var ${itemTypeVar} in ${var_name} )
                {
                    <@sizeText var_name="${n}Item" type=genericType isNullable=containsNullable/>
                }
        <#break >
    <#case "MAPENTRY">
        <#local keyType = util.getFirstGenericParameterType(type)>
        <#local valueType = util.getSecondGenericParameterType(type)>
        <#local n= var_name>
        <#local keyName="${var_name}Key">
        <#local valName="${var_name}Val">
                var ${keyName} = ${var_name}.Key;
                var ${valName} = ${var_name}.Value;
                <@sizeText var_name=keyName  type=keyType/>
                <@sizeText var_name=valName  type=valueType/>
</#switch>
</#macro>
<#--SETTER NULL CHECK MACRO -->
<#macro setterText var_name type isNullable=false containsNullable=false>
<#if isNullable>
            clientMessage.Set(${var_name} == null);
            if (${var_name} != null)
            {
</#if>
    <@setterTextInternal var_name=var_name type=type containsNullable=containsNullable/>
<#if isNullable>
            }
</#if>
</#macro>
<#--SETTER MACRO -->
<#macro setterTextInternal var_name type isNullable=false containsNullable=false>
    <#local cat= util.getTypeCategory(type)>
    <#if cat == "OTHER">
            clientMessage.Set(${var_name});
    </#if>
    <#if cat == "CUSTOM">
            ${util.getTypeCodec(type)?split(".")?last}.Encode(${var_name}, clientMessage);
    </#if>
    <#if cat == "COLLECTION">
            clientMessage.Set(${var_name}.Count);
            <#local itemType= util.getGenericType(type)>
            <#local itemTypeVar= var_name + "Item">
            foreach (var ${itemTypeVar} in ${var_name})
            {
                <@setterTextInternal var_name=itemTypeVar type=itemType isNullable=containsNullable/>
            }
    </#if>
    <#if cat == "ARRAY">
            clientMessage.Set(${var_name}.length);
            <#local itemType= util.getArrayType(type)>
            <#local itemTypeVar= var_name + "Item">
            foreach (var ${itemTypeVar} in ${var_name})
            {
                <@setterTextInternal var_name=itemTypeVar type=itemType isNullable=containsNullable/>
            }
    </#if>
    <#if cat == "MAPENTRY">
        <#local keyType = util.getFirstGenericParameterType(type)>
        <#local valueType = util.getSecondGenericParameterType(type)>
        <#local n= var_name>
        <#local keyName="${var_name}Key">
        <#local valName="${var_name}Val">
            var ${keyName} = ${var_name}.Key;
            var ${valName} = ${var_name}.Value;
        <@setterTextInternal var_name=keyName  type=keyType/>
        <@setterTextInternal var_name=valName  type=valueType/>
    </#if>
</#macro>
<#--GETTER NULL CHECK MACRO -->
<#macro getterText var_name type isNullable=false isEvent=false containsNullable=false>
<#--<@defineVariable var_name=var_name type=type/>-->
<@readVariable var_name=var_name type=type isNullable=isNullable isEvent=isEvent containsNullable=containsNullable/>
</#macro>
<#-- Only defines the variable -->
<#macro defineVariable var_name type is_optional=false>
        ${util.getCSharpType(type)}<#if is_optional && util.isPrimitive(type)>?</#if> ${var_name};
</#macro>
<#function defineVariableFnc var_name type is_optional=false>
    <#if !is_optional>
        <#return util.getCSharpType(type) + " " + var_name>
    <#elseif is_optional && util.isNonNullable(type)>
        <#return util.getCSharpType(type) + "? " + var_name>
    <#elseif is_optional && !util.isNonNullable(type)>
        <#return util.getCSharpType(type) + " " + var_name>
    </#if>
</#function>
<#-- Reads the variable from client message -->
<#macro readVariable var_name type isNullable isEvent containsNullable=false local=true>
<#local isNullVariableName= "${var_name}IsNull">
<#if isNullable>
    var ${isNullVariableName} = clientMessage.GetBoolean();
    if (!${isNullVariableName})
    {
</#if>
    <@getterTextInternal var_name=var_name varType=type containsNullable=containsNullable local=local/>
<#if !isEvent>
    parameters.${var_name} = ${var_name};
</#if>
<#if isNullable>
    }
</#if>
</#macro>
<#macro getterTextInternal var_name varType containsNullable=false local=true>
<#local cat= util.getTypeCategory(varType)>
<#switch cat>
    <#case "OTHER">
        <#switch varType>
            <#case util.DATA_FULL_NAME>
            <#if local>var </#if>${var_name} = clientMessage.GetData();
                <#break >
            <#case "java.lang.Integer">
            <#if local>var </#if>${var_name} = clientMessage.GetInt();
                <#break >
            <#case "java.lang.Long">
            <#if local>var </#if>${var_name} = clientMessage.GetLong();
                <#break >
            <#case "java.lang.Boolean">
            <#if local>var </#if>${var_name} = clientMessage.GetBoolean();
                <#break >
            <#case "java.lang.String">
            <#if local>var </#if>${var_name} = clientMessage.GetStringUtf8();
                <#break >
            <#default>
            <#if local>var </#if>${var_name} = clientMessage.Get${util.capitalizeFirstLetter(varType)}();
        </#switch>
        <#break >
    <#case "CUSTOM">
            <#if local>var </#if>${var_name} = ${util.getTypeCodec(varType)?split(".")?last}.Decode(clientMessage);
        <#break >
    <#case "COLLECTION">
    <#local collectionType><#if varType?starts_with("java.util.List")>List<#else>HashSet</#if></#local>
    <#local itemVariableType= util.getGenericType(varType)>
    <#local convertedItemType= util.getCSharpType(itemVariableType)>
    <#local itemVariableName= "${var_name}Item">
    <#local sizeVariableName= "${var_name}Size">
    <#local indexVariableName= "${var_name}Index">
    <#local isNullVariableName= "${itemVariableName}IsNull">
            <#if local>var </#if>${var_name} = new ${collectionType}<${convertedItemType}>(${itemVariableType.startsWith("List")?then(sizeVariableName,"")});
            var ${sizeVariableName} = clientMessage.GetInt();
            for (var ${indexVariableName} = 0; ${indexVariableName}<${sizeVariableName}; ${indexVariableName}++)
            {
                <#if containsNullable>
                var ${isNullVariableName} = clientMessage.GetBoolean();
                if (!${isNullVariableName})
                {
                </#if>
                    <@getterTextInternal var_name=itemVariableName varType=itemVariableType/>
                    ${var_name}.Add(${itemVariableName});
                <#if containsNullable>
                }
                else
                {
                    ${var_name}.Add(null);
                }
                </#if>
            }
        <#break >
    <#case "ARRAY">
    <#local itemVariableType= util.getArrayType(varType)>
    <#local itemVariableName= "${var_name}Item">
    <#local sizeVariableName= "${var_name}Size">
    <#local indexVariableName= "${var_name}Index">
    <#local isNullVariableName= "${itemVariableName}IsNull">
            <#if local>var </#if>${var_name} = new ${itemVariableType}[${sizeVariableName}];
            var ${sizeVariableName} = clientMessage.GetInt();
            for (var ${indexVariableName} = 0; ${indexVariableName}<${sizeVariableName}; ${indexVariableName}++)
            {
                <#if containsNullable>
                var ${isNullVariableName} = clientMessage.GetBoolean();
                if (!${isNullVariableName})
                {
                </#if>
                    <@getterTextInternal var_name=itemVariableName varType=itemVariableType/>
                    ${var_name}.Add(${itemVariableName});
                <#if containsNullable>
                }
                else
                {
                    ${var_name}.Add(null);
                }
                </#if>
            }
        <#break >
    <#case "MAPENTRY">
        <#local sizeVariableName= "${var_name}Size">
        <#local indexVariableName= "${var_name}Index">
        <#local keyType = util.getFirstGenericParameterType(varType)>
        <#local keyTypeCs = util.getCSharpType(keyType)>
        <#local valueType = util.getSecondGenericParameterType(varType)>
        <#local valueTypeCs = util.getCSharpType(valueType)>
        <#local keyVariableName= "${var_name}Key">
        <#local valVariableName= "${var_name}Val">
        <@getterTextInternal var_name=keyVariableName varType=keyType/>
        <@getterTextInternal var_name=valVariableName varType=valueType/>
        <#if local>var </#if>${var_name} = new KeyValuePair<${keyTypeCs},${valueTypeCs}>(${keyVariableName}, ${valVariableName});
</#switch>
</#macro>