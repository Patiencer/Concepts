{***************************************************************************}
{                                                                           }
{           Spring Framework for Delphi                                     }
{                                                                           }
{           Copyright (c) 2009-2016 Spring4D Team                           }
{                                                                           }
{           http://www.spring4d.org                                         }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Licensed under the Apache License, Version 2.0 (the "License");          }
{  you may not use this file except in compliance with the License.         }
{  You may obtain a copy of the License at                                  }
{                                                                           }
{      http://www.apache.org/licenses/LICENSE-2.0                           }
{                                                                           }
{  Unless required by applicable law or agreed to in writing, software      }
{  distributed under the License is distributed on an "AS IS" BASIS,        }
{  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. }
{  See the License for the specific language governing permissions and      }
{  limitations under the License.                                           }
{                                                                           }
{***************************************************************************}

{$I Spring.inc}

unit Spring.Persistence.SQL.Generators.MSSQL;

interface

uses
  Spring.Persistence.Mapping.Attributes,
  Spring.Persistence.SQL.Generators.Ansi,
  Spring.Persistence.SQL.Interfaces,
  Spring.Persistence.SQL.Types;

type
  /// <summary>
  ///   Represents <b>Microsoft SQL Server</b> SQL generator.
  /// </summary>
  TMSSQLServerSQLGenerator = class(TAnsiSQLGenerator)
  public
    function GetQueryLanguage: TQueryLanguage; override;
    function GenerateGetLastInsertId(const identityColumn: ColumnAttribute): string; override;
    function GeneratePagedQuery(const sql: string; limit, offset: Integer): string; override;
    function GetSQLDataTypeName(const field: TSQLCreateField): string; override;
    function GetTempTableName: string; override;
    function GetPrimaryKeyDefinition(const field: TSQLCreateField): string; override;
    function GetSQLTableExists(const tableName: string): string; override;
  end;

implementation

uses
  StrUtils,
  SysUtils,
  Spring.Persistence.SQL.Register;


{$REGION 'TMSSQLServerSQLGenerator'}

function TMSSQLServerSQLGenerator.GenerateGetLastInsertId(
  const identityColumn: ColumnAttribute): string;
begin
  Result := 'SELECT CAST( SCOPE_IDENTITY() AS BIGINT);';
end;

function TMSSQLServerSQLGenerator.GeneratePagedQuery(const sql: string;
  limit, offset: Integer): string;
var
  LBuilder: TStringBuilder;
  LSQL: string;
begin
  LBuilder := TStringBuilder.Create;
  LSQL := sql;
  try
    if EndsStr(';', LSQL) then
      SetLength(LSQL, Length(LSQL)-1);

    LBuilder.Append('SELECT * FROM (')
      .AppendLine
      .Append('  SELECT *, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS ORM_ROW_NUM FROM (')
      .AppendLine.Append('    ')
      .Append(LSQL)
      .Append(') AS ORM_TOTAL_1')
      .AppendLine
      .Append('  ) AS ORM_TOTAL_2')
      .AppendLine
      .AppendFormat(' WHERE (ORM_ROW_NUM > %0:d) AND (ORM_ROW_NUM <= %0:d + %1:d);', [offset, limit]);

    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function TMSSQLServerSQLGenerator.GetPrimaryKeyDefinition(
  const field: TSQLCreateField): string;
begin
  Result := Format('CONSTRAINT PK_%0:s_%1:s PRIMARY KEY',
    [field.Table.NameWithoutSchema, field.Name]);
end;

function TMSSQLServerSQLGenerator.GetQueryLanguage: TQueryLanguage;
begin
  Result := qlMSSQL;
end;

function TMSSQLServerSQLGenerator.GetSQLDataTypeName(
  const field: TSQLCreateField): string;
begin
  Result := inherited GetSQLDataTypeName(field);
  if Result = 'BLOB' then
    Result := 'IMAGE'
  else if Result = 'TIMESTAMP' then
    Result := 'DATETIME';

  if field.IsIdentity then
    Result := Result + ' IDENTITY(1,1)';
end;

function TMSSQLServerSQLGenerator.GetSQLTableExists(const tableName: string): string;
var
  LSchema, LTable: string;
begin
  ParseFullTablename(tableName, LTable, LSchema);
  if (LSchema <> '') then
    Result := Format('SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = %1:s AND TABLE_NAME = %0:s '
    , [QuotedStr(LTable), QuotedStr(LSchema)])
  else
    Result := Format('SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = %0:s'
    , [QuotedStr(LTable)]);
end;

function TMSSQLServerSQLGenerator.GetTempTableName: string;
begin
  Result := '#' + inherited GetTempTableName;
end;

{$ENDREGION}


initialization
  TSQLGeneratorRegister.RegisterGenerator(TMSSQLServerSQLGenerator.Create);

end.
